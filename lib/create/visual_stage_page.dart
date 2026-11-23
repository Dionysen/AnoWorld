import 'dart:async';
import 'dart:io';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/visual_asset_preview.dart';
import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:anoworld/domain/ai/visual/visual_image_pipeline.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_actions.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_image.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:flutter/material.dart';

/// Stage 4: controlled image prompts → ComfyUI portraits + scene backgrounds.
class VisualStagePage extends StatefulWidget {
  const VisualStagePage({super.key, required this.projectId});

  final String projectId;

  @override
  State<VisualStagePage> createState() => _VisualStagePageState();
}

class _VisualStagePageState extends State<VisualStagePage> {
  Project? _project;
  String? _projectDir;
  VisualPromptPlan? _plan;
  Object? _error;
  String? _status;
  double? _progress;
  bool _loading = true;
  bool _loadScheduled = false;
  bool _busyPrompts = false;
  bool _busyImages = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppScope is an inherited widget: reading it in initState throws.
    if (_loadScheduled) return;
    _loadScheduled = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = AppScope.projectsOf(context);
      final project = await projects.open(widget.projectId);
      final dir = await projects.directoryFor(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _projectDir = dir;
        _plan = draftPlanFromProjectFields(project);
        _loading = false;
      });
    } catch (error, stack) {
      AppLog.instance.error(
        '打开画面页失败',
        tag: 'visual.stage',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _generatePrompts() async {
    final project = _project;
    if (project == null) return;
    final strings = context.strings;
    if (project.cast.isEmpty) {
      showAppToast(context, strings.visualStageNeedCast);
      return;
    }
    if (project.main.nodes.isEmpty) {
      showAppToast(context, strings.visualStageNeedNodes);
      return;
    }
    setState(() {
      _busyPrompts = true;
      _progress = null;
      _status = strings.visualStageBusyPrompts;
    });
    AppLog.instance.info('生成画面提示词', tag: 'visual.prompts');
    try {
      final settings = AppScope.settingsOf(context);
      final actions = VisualPromptActions(
        textClient: AppScope.textClientOf(context),
      );
      final plan = await actions.generatePlan(
        ctx: settings.textPromptContext(),
        project: project,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _busyPrompts = false;
        _status = null;
      });
      await _savePlan(plan);
      if (!mounted) return;
      AppLog.instance.info('画面提示词已生成', tag: 'visual.prompts');
      showAppToast(context, strings.visualStagePromptsSaved);
    } catch (error, stack) {
      AppLog.instance.error(
        '生成画面提示词失败',
        tag: 'visual.prompts',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _busyPrompts = false;
        _status = null;
      });
      showAppToast(context, error.toString());
    }
  }

  Future<void> _generateImages() async {
    final project = _project;
    final plan = _plan;
    final strings = context.strings;
    if (project == null || plan == null) return;
    if (project.cast.isEmpty) {
      showAppToast(context, strings.visualStageNeedCast);
      return;
    }
    if (project.main.nodes.isEmpty) {
      showAppToast(context, strings.visualStageNeedNodes);
      return;
    }
    if (!plan.isComplete) {
      showAppToast(context, strings.visualStageNeedPrompts);
      return;
    }
    final image = AppScope.settingsOf(context).ai.image;
    if (image.kind != AiImageProviderKind.comfyui || !image.isConfigured) {
      showAppToast(context, strings.visualStageNeedComfy);
      return;
    }
    final projects = AppScope.projectsOf(context);
    final changes = AppScope.projectChangesOf(context);
    setState(() {
      _busyImages = true;
      _progress = 0;
      _status = strings.visualStageBusyImages;
    });
    AppLog.instance.info('开始生成画面图片', tag: 'visual.images');
    try {
      final dir = _projectDir ?? await projects.directoryFor(widget.projectId);
      if (dir == null || dir.isEmpty) {
        throw const VisualImageException('找不到故事文件夹');
      }
      final next = await VisualImagePipeline().run(
        project: project,
        projectDir: dir,
        image: image,
        plan: plan,
        skipExisting: true,
        onProgress: (message, progress) {
          if (!mounted) return;
          setState(() {
            _status = message;
            _progress = progress;
          });
        },
      );
      final saved = await saveProjectMerged(
        projects,
        widget.projectId,
        (latest) => latest.copyWith(
          cast: next.cast,
          assets: next.assets,
          main: next.main,
        ),
      );
      if (!mounted) return;
      changes.markChanged(widget.projectId);
      setState(() {
        _project = saved;
        _plan = draftPlanFromProjectFields(saved);
        _busyImages = false;
        _status = null;
        _progress = null;
      });
      AppLog.instance.info('画面图片已写入', tag: 'visual.images');
      showAppToast(context, strings.visualStageImagesDone);
    } catch (error, stack) {
      AppLog.instance.error(
        '生成画面图片失败',
        tag: 'visual.images',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _busyImages = false;
        _status = null;
        _progress = null;
      });
      showAppToast(context, error.toString());
    }
  }

  /// Auto-save: prompts are the layer this page owns.
  Future<void> _savePlan(VisualPromptPlan plan) async {
    final saved = await saveProjectMerged(
      AppScope.projectsOf(context),
      widget.projectId,
      (latest) => applyVisualPromptPlan(latest, plan),
    );
    if (!mounted) return;
    AppScope.projectChangesOf(context).markChanged(widget.projectId);
    setState(() => _project = saved);
  }

  File? _assetFile(Project project, String? assetId) {
    final dir = _projectDir;
    final id = assetId?.trim();
    if (dir == null || id == null || id.isEmpty) return null;
    return ProjectAssetFiles.tryFile(
      projectDir: dir,
      asset: project.assetById(id),
    );
  }

  List<_VisualRow> _styleRows(VisualPromptPlan plan) {
    final strings = context.strings;
    return [
      _VisualRow(
        title: strings.visualStageStylePrefix,
        prompt: plan.stylePrefix,
        icon: Icons.palette_outlined,
        missingLabel: strings.visualStageNoPrompt,
        target: VisualPromptTarget.stylePrefix,
        apply: (next, prompt, _) => next.copyWith(stylePrefix: prompt),
      ),
      _VisualRow(
        title: strings.visualStageNegative,
        prompt: plan.negativePrompt,
        icon: Icons.block,
        missingLabel: strings.visualStageNoPrompt,
        target: VisualPromptTarget.negativePrompt,
        apply: (next, prompt, _) => next.copyWith(negativePrompt: prompt),
      ),
    ];
  }

  List<_VisualRow> _portraitRows(Project project, VisualPromptPlan plan) {
    final strings = context.strings;
    return [
      for (final row in plan.characters)
        _VisualRow(
          title: row.name,
          prompt: row.portraitPrompt,
          icon: Icons.person_outline,
          missingLabel: strings.visualNoPortrait,
          showsImage: true,
          target: VisualPromptTarget.portrait,
          characterId: row.characterId,
          file: _assetFile(
            project,
            project.castById(row.characterId)?.avatarAssetId,
          ),
          facing: row.facing,
          previewFit: BoxFit.contain,
          apply: (next, prompt, facing) {
            final portrait =
                ComfyWorkflowTemplates.enforcePortraitFraming(prompt);
            return next.copyWith(
              characters: [
                for (final c in next.characters)
                  c.characterId == row.characterId
                      ? c.copyWith(
                          portraitPrompt: portrait,
                          facing: facing ?? c.facing,
                        )
                      : c,
              ],
            );
          },
        ),
    ];
  }

  List<_VisualRow> _sceneRows(Project project, VisualPromptPlan plan) {
    final strings = context.strings;
    return [
      for (final row in plan.scenes)
        _VisualRow(
          title: row.title,
          prompt: row.scenePrompt,
          icon: Icons.image_outlined,
          missingLabel: strings.visualNoScene,
          showsImage: true,
          target: VisualPromptTarget.scene,
          nodeId: row.nodeId,
          file: _assetFile(
            project,
            project.main.nodeById(row.nodeId)?.backgroundAssetId,
          ),
          apply: (next, prompt, _) => next.copyWith(
            scenes: [
              for (final s in next.scenes)
                s.nodeId == row.nodeId ? s.copyWith(scenePrompt: prompt) : s,
            ],
          ),
        ),
    ];
  }

  Future<void> _editRow(_VisualRow row) async {
    final plan = _plan;
    if (plan == null) return;
    final edit = await showAppSheet<_PromptEdit>(
      context: context,
      size: AppSheetSize.full,
      builder: (_) => _PromptSheet(
        row: row,
        onRegeneratePrompt: (current) => _regeneratePrompt(row, current),
        onRegenerateImage:
            row.showsImage ? (prompt) => _regenerateImage(row, prompt) : null,
      ),
    );
    if (edit == null || !mounted) return;
    final next = row.apply(plan, edit.prompt, edit.facing);
    setState(() => _plan = next);
    AppLog.instance.info('改画面提示词：${row.title}', tag: 'visual.stage');
    try {
      await _savePlan(next);
    } catch (error, stack) {
      AppLog.instance.error(
        '保存画面提示词失败',
        tag: 'visual.stage',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      showAppToast(context, context.strings.visualPromptSaveFailed);
    }
  }

  /// One-row prompt rewrite; returns the new text without saving it.
  Future<String?> _regeneratePrompt(_VisualRow row, String current) async {
    final project = _project;
    final plan = _plan;
    if (project == null || plan == null) return null;
    final strings = context.strings;
    try {
      final actions = VisualPromptActions(
        textClient: AppScope.textClientOf(context),
      );
      final prompt = await actions.regeneratePrompt(
        ctx: AppScope.settingsOf(context).textPromptContext(),
        project: project,
        plan: plan,
        target: row.target,
        current: current,
        characterId: row.characterId,
        nodeId: row.nodeId,
      );
      AppLog.instance.info('重写提示词：${row.title}', tag: 'visual.prompts');
      if (!mounted) return prompt;
      showAppToast(context, strings.visualPromptRegenDone);
      return prompt;
    } catch (error, stack) {
      AppLog.instance.error(
        '重写提示词失败：${row.title}',
        tag: 'visual.prompts',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return null;
      showAppToast(context, error.toString());
      return null;
    }
  }

  /// Redraws one picture with [prompt] after saving that prompt.
  Future<File?> _regenerateImage(_VisualRow row, String prompt) async {
    final project = _project;
    final plan = _plan;
    final characterId = row.characterId;
    final nodeId = row.nodeId;
    if (project == null || plan == null) return null;
    final strings = context.strings;
    if (prompt.trim().isEmpty) {
      showAppToast(context, strings.visualStageNeedPrompts);
      return null;
    }
    final image = AppScope.settingsOf(context).ai.image;
    if (image.kind != AiImageProviderKind.comfyui || !image.isConfigured) {
      showAppToast(context, strings.visualStageNeedComfy);
      return null;
    }
    final projects = AppScope.projectsOf(context);
    final changes = AppScope.projectChangesOf(context);
    try {
      final dir = _projectDir ?? await projects.directoryFor(widget.projectId);
      if (dir == null || dir.isEmpty) {
        throw const VisualImageException('找不到故事文件夹');
      }
      final nextPlan = row.apply(plan, prompt, row.facing);
      final latest = await saveProjectMerged(
        projects,
        widget.projectId,
        (stored) => applyVisualPromptPlan(stored, nextPlan),
      );
      AppLog.instance.info('重画${row.title}', tag: 'visual.regen');
      final pipeline = VisualImagePipeline();
      final redrawn = switch (row.target) {
        VisualPromptTarget.portrait => await pipeline.regenerateAvatar(
            project: latest,
            projectDir: dir,
            image: image,
            characterId: characterId!,
            prompt: prompt,
          ),
        VisualPromptTarget.scene => await pipeline.regenerateScene(
            project: latest,
            projectDir: dir,
            image: image,
            nodeId: nodeId!,
            prompt: prompt,
          ),
        VisualPromptTarget.stylePrefix ||
        VisualPromptTarget.negativePrompt =>
          throw const VisualImageException('这一行没有图片'),
      };
      final saved = await saveProjectMerged(
        projects,
        widget.projectId,
        (stored) => stored.copyWith(
          cast: redrawn.cast,
          assets: redrawn.assets,
          main: redrawn.main,
        ),
      );
      if (!mounted) return null;
      changes.markChanged(widget.projectId);
      setState(() {
        _project = saved;
        _plan = row.apply(plan, prompt, row.facing);
      });
      showAppToast(context, strings.visualImageRegenDone);
      return _assetFile(
        saved,
        row.target == VisualPromptTarget.portrait
            ? saved.castById(characterId!)?.avatarAssetId
            : saved.main.nodeById(nodeId!)?.backgroundAssetId,
      );
    } catch (error, stack) {
      AppLog.instance.error(
        '重画失败：${row.title}',
        tag: 'visual.regen',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return null;
      showAppToast(context, error.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final project = _project;
    final plan = _plan;
    final busy = _busyPrompts || _busyImages;
    return AppPage(
      title: strings.visualStageTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          if (_loading)
            AppPageGutter(
              child: AppText(strings.loading, role: AppTextRole.caption),
            )
          else if (project == null || plan == null)
            AppPageGutter(
              child: AppEmptyState(
                message: strings.openStoryFailed,
                detail: _error?.toString(),
                action: AppButton(
                  label: strings.retry,
                  onPressed: _load,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            )
          else ...[
            AppPageGutter(
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: strings.visualStageWritePrompts,
                      onPressed: busy ? null : _generatePrompts,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: AppButton(
                      label: strings.visualStageGenerateImages,
                      variant: AppButtonVariant.secondary,
                      onPressed: busy ? null : _generateImages,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              AppPageGutter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spaceInline),
                  child: Row(
                    children: [
                      const AppBusyIndicator(size: 16, padding: EdgeInsets.zero),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: AppText(
                          _busyLabel(_status),
                          role: AppTextRole.caption,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ..._sections(strings, project, plan, busy),
          ],
        ],
      ),
    );
  }

  String _busyLabel(String? status) {
    final text = status?.trim() ?? '';
    final progress = _progress;
    if (progress == null) return text;
    final pct = '${(progress * 100).round()}%';
    return text.isEmpty ? pct : '$text · $pct';
  }

  List<Widget> _sections(
    AppStrings strings,
    Project project,
    VisualPromptPlan plan,
    bool busy,
  ) {
    final portraits = _portraitRows(project, plan);
    final scenes = _sceneRows(project, plan);

    Widget stack(List<_VisualRow> items) => AppListTileStack(
          tiles: [
            for (final row in items)
              AppListTile(
                title: row.title,
                subtitle: row.subtitle,
                leading: row.showsImage
                    ? _VisualThumb(file: row.file, icon: row.icon)
                    : null,
                icon: row.showsImage ? null : row.icon,
                trailing: const AppForwardIcon(),
                onTap: busy ? null : () => _editRow(row),
              ),
          ],
        );

    return [
      Padding(
        padding: const EdgeInsets.only(top: AppTheme.spaceMd),
        child: AppSectionHeader(strings.visualStageStyleSection, gutter: true),
      ),
      stack(_styleRows(plan)),
      if (portraits.isNotEmpty) ...[
        const SizedBox(height: AppTheme.spaceMd),
        AppSectionHeader(strings.visualStagePortraitSection, gutter: true),
        stack(portraits),
      ],
      if (scenes.isNotEmpty) ...[
        const SizedBox(height: AppTheme.spaceMd),
        AppSectionHeader(strings.visualStageSceneSection, gutter: true),
        stack(scenes),
      ],
    ];
  }
}

/// One prompt row on the list: image (or icon), title, prompt preview.
class _VisualRow {
  const _VisualRow({
    required this.title,
    required this.prompt,
    required this.icon,
    required this.missingLabel,
    required this.target,
    required this.apply,
    this.showsImage = false,
    this.file,
    this.characterId,
    this.nodeId,
    this.facing,
    this.previewFit = BoxFit.cover,
  });

  final String title;
  final String prompt;
  final IconData icon;

  /// Shown as the preview when the prompt is still empty.
  final String missingLabel;

  /// Which plan field this row rewrites.
  final VisualPromptTarget target;

  /// Rewrites this row inside a plan (auto-saved by the page).
  final VisualPromptPlan Function(
    VisualPromptPlan plan,
    String prompt,
    SpriteFacing? facing,
  ) apply;

  /// True for picture rows (portrait / scene); prompt-only rows use [icon].
  final bool showsImage;

  /// Generated picture for this row, when it has one.
  final File? file;

  /// Portrait rows: the cast member whose picture this row draws.
  final String? characterId;

  /// Scene rows: the story node whose picture this row draws.
  final String? nodeId;

  /// Set on portrait rows: the look direction baked into the prompt.
  final SpriteFacing? facing;

  final BoxFit previewFit;

  String get subtitle {
    final text = prompt.trim();
    return text.isEmpty ? missingLabel : text;
  }
}

/// Save result of the prompt sheet.
class _PromptEdit {
  const _PromptEdit({required this.prompt, this.facing});

  final String prompt;
  final SpriteFacing? facing;
}

class _PromptSheet extends StatefulWidget {
  const _PromptSheet({
    required this.row,
    required this.onRegeneratePrompt,
    this.onRegenerateImage,
  });

  final _VisualRow row;

  /// Fresh prompt for this row only (unsaved until **保存**).
  final Future<String?> Function(String current) onRegeneratePrompt;

  /// Redraws this row's picture with [prompt]; null when the row has none.
  final Future<File?> Function(String prompt)? onRegenerateImage;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late final TextEditingController _controller;
  late String _initial;
  late SpriteFacing? _facing;
  late File? _file;
  bool _promptBusy = false;
  bool _imageBusy = false;

  @override
  void initState() {
    super.initState();
    _initial = widget.row.prompt.trim();
    _controller = TextEditingController(text: _initial);
    _facing = widget.row.facing;
    _file = widget.row.file;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _controller.text.trim() != _initial || _facing != widget.row.facing;

  bool get _busy => _promptBusy || _imageBusy;

  void _setFacing(SpriteFacing facing) {
    setState(() {
      _facing = facing;
      _controller.text = ComfyWorkflowTemplates.applyFacingToPortraitPrompt(
        _controller.text,
        facing,
      );
    });
  }

  Future<void> _regenPrompt() async {
    setState(() => _promptBusy = true);
    final prompt = await widget.onRegeneratePrompt(_controller.text.trim());
    if (!mounted) return;
    setState(() {
      _promptBusy = false;
      if (prompt != null && prompt.isNotEmpty) _controller.text = prompt;
    });
  }

  Future<void> _regenImage() async {
    final draw = widget.onRegenerateImage;
    if (draw == null) return;
    final prompt = _controller.text.trim();
    setState(() => _imageBusy = true);
    final file = await draw(prompt);
    if (!mounted) return;
    setState(() {
      _imageBusy = false;
      if (file != null) {
        _file = file;
        // The prompt was saved along with the picture.
        _initial = prompt;
      }
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _PromptEdit(prompt: _controller.text.trim(), facing: _facing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final row = widget.row;
    final draw = widget.onRegenerateImage;
    return AppSheetEditForm(
      title: row.title,
      isDirty: _dirty,
      onSave: _save,
      body: AppSheetScrollBody(
        children: [
          if (row.showsImage) ...[
            VisualAssetPreview(
              file: _file,
              emptyLabel: row.missingLabel,
              height: 160,
              fit: row.previewFit,
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: strings.visualPromptRegen,
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : _regenPrompt,
                ),
              ),
              if (draw != null) ...[
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: strings.visualImageRegen,
                    variant: AppButtonVariant.secondary,
                    onPressed: _busy ? null : _regenImage,
                  ),
                ),
              ],
            ],
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceInline),
              child: Row(
                children: [
                  const AppBusyIndicator(size: 16, padding: EdgeInsets.zero),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: AppText(
                      _imageBusy
                          ? strings.visualStageBusyImages
                          : strings.visualStageBusyPrompts,
                      role: AppTextRole.caption,
                    ),
                  ),
                ],
              ),
            ),
          if (row.facing != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            AppOptionGroup<SpriteFacing>(
              label: strings.visualStageFacing,
              value: _facing ?? SpriteFacing.right,
              options: [
                AppSegmentOption(
                  value: SpriteFacing.right,
                  label: strings.visualStageFacingRight,
                ),
                AppSegmentOption(
                  value: SpriteFacing.left,
                  label: strings.visualStageFacingLeft,
                ),
              ],
              onChanged: _setFacing,
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          AppTextField(
            label: strings.visualPromptLabel,
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

/// Square row thumbnail: picture when generated, glyph placeholder otherwise.
class _VisualThumb extends StatelessWidget {
  const _VisualThumb({required this.file, required this.icon});

  static const double size = 56;

  final File? file;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = AppUiTokens.of(context).radius;
    final fallback = Icon(icon, size: 20, color: scheme.onSurfaceVariant);
    final path = file?.path;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: path == null
              ? Center(child: fallback)
              : AppImage(path: path, fit: BoxFit.cover, fallback: fallback),
        ),
      ),
    );
  }
}
