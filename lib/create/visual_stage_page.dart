import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:anoworld/domain/ai/visual/visual_image_pipeline.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_actions.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
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
  VisualPromptPlan? _plan;
  Object? _error;
  String? _status;
  double? _progress;
  bool _loading = true;
  bool _busyPrompts = false;
  bool _busyImages = false;
  bool _skipExisting = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project =
          await AppScope.projectsOf(context).open(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _plan = planFromProjectFields(project);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _writePrompts() async {
    final project = _project;
    if (project == null) return;
    final strings = context.strings;
    if (project.cast.isEmpty) {
      setState(() => _error = strings.visualStageNeedCast);
      return;
    }
    if (project.main.nodes.isEmpty) {
      setState(() => _error = strings.visualStageNeedNodes);
      return;
    }
    setState(() {
      _busyPrompts = true;
      _error = null;
      _status = strings.visualStageBusyPrompts;
    });
    try {
      final settings = AppScope.settingsOf(context);
      final ctx = settings.textPromptContext();
      final actions = VisualPromptActions(
        textClient: AppScope.textClientOf(context),
      );
      final plan = await actions.generatePlan(ctx: ctx, project: project);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _busyPrompts = false;
        _status = strings.visualStagePromptsReady;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyPrompts = false;
        _error = error;
        _status = null;
      });
    }
  }

  Future<void> _savePromptsOnly() async {
    final project = _project;
    final plan = _plan;
    if (project == null || plan == null) return;
    final projects = AppScope.projectsOf(context);
    final changes = AppScope.projectChangesOf(context);
    final savedLabel = context.strings.visualStageSavePrompts;
    final next = applyVisualPromptPlan(project, plan);
    await projects.save(next);
    changes.markChanged(widget.projectId);
    if (!mounted) return;
    setState(() {
      _project = next;
      _status = savedLabel;
    });
  }

  Future<void> _generateImages() async {
    final project = _project;
    var plan = _plan;
    final strings = context.strings;
    if (project == null) return;
    plan ??= planFromProjectFields(project);
    if (plan == null) {
      setState(() => _error = '请先生成或填写提示词');
      return;
    }
    final image = AppScope.settingsOf(context).ai.image;
    if (image.kind != AiImageProviderKind.comfyui || !image.isConfigured) {
      setState(() => _error = strings.visualStageNeedComfy);
      return;
    }
    setState(() {
      _busyImages = true;
      _error = null;
      _status = strings.visualStageBusyImages;
      _progress = 0;
      _plan = plan;
    });
    try {
      final projects = AppScope.projectsOf(context);
      final changes = AppScope.projectChangesOf(context);
      final doneLabel = strings.visualStageImagesDone;
      final dir = await projects.directoryFor(widget.projectId);
      if (dir == null || dir.isEmpty) {
        throw const VisualImageException('找不到故事文件夹');
      }
      final pipeline = VisualImagePipeline();
      final next = await pipeline.run(
        project: project,
        projectDir: dir,
        image: image,
        plan: plan,
        skipExisting: _skipExisting,
        onProgress: (message, progress) {
          if (!mounted) return;
          setState(() {
            _status = message;
            _progress = progress;
          });
        },
      );
      await projects.save(next);
      changes.markChanged(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = next;
        _busyImages = false;
        _status = doneLabel;
        _progress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyImages = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final busy = _busyPrompts || _busyImages;
    return AppPage(
      title: strings.visualStageTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          AppPageGutter(
            child: AppText(
              strings.visualStageBlurb,
              role: AppTextRole.caption,
            ),
          ),
          if (_loading)
            AppPageGutter(
              child: AppText(strings.loading, role: AppTextRole.caption),
            )
          else if (_project == null)
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
              child: Wrap(
                spacing: AppTheme.spaceSm,
                runSpacing: AppTheme.spaceSm,
                children: [
                  AppButton(
                    label: strings.visualStageWritePrompts,
                    onPressed: busy ? null : _writePrompts,
                  ),
                  AppButton(
                    label: strings.visualStageSavePrompts,
                    onPressed: busy || _plan == null ? null : _savePromptsOnly,
                    variant: AppButtonVariant.secondary,
                  ),
                  AppButton(
                    label: strings.visualStageGenerateImages,
                    onPressed: busy || _plan == null ? null : _generateImages,
                  ),
                ],
              ),
            ),
            AppPageGutter(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.visualStageSkipExisting),
                value: _skipExisting,
                onChanged:
                    busy ? null : (v) => setState(() => _skipExisting = v),
              ),
            ),
            if (_status != null)
              AppPageGutter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppText(_status!, role: AppTextRole.caption),
                    if (_progress != null) ...[
                      const SizedBox(height: AppTheme.spaceSm),
                      LinearProgressIndicator(value: _progress),
                    ],
                  ],
                ),
              ),
            if (_error != null)
              AppPageGutter(
                child: AppText(
                  _error.toString(),
                  role: AppTextRole.caption,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (_plan != null) ..._planEditors(strings, _plan!, busy),
          ],
        ],
      ),
    );
  }

  List<Widget> _planEditors(
    AppStrings strings,
    VisualPromptPlan plan,
    bool busy,
  ) {
    return [
      AppPageGutter(
        child: _EditableBlock(
          key: ValueKey('style-${plan.stylePrefix.hashCode}'),
          label: strings.visualStageStylePrefix,
          initial: plan.stylePrefix,
          maxLines: 3,
          enabled: !busy,
          onChanged: (v) => setState(() {
            final current = _plan;
            if (current == null) return;
            _plan = current.copyWith(stylePrefix: v);
          }),
        ),
      ),
      AppPageGutter(
        child: _EditableBlock(
          key: ValueKey('neg-${plan.negativePrompt.hashCode}'),
          label: strings.visualStageNegative,
          initial: plan.negativePrompt,
          maxLines: 3,
          enabled: !busy,
          onChanged: (v) => setState(() {
            final current = _plan;
            if (current == null) return;
            _plan = current.copyWith(negativePrompt: v);
          }),
        ),
      ),
      for (var i = 0; i < plan.characters.length; i++) ...[
        AppPageGutter(
          child: _EditableBlock(
            key: ValueKey('tags-${plan.characters[i].characterId}'),
            label: '${plan.characters[i].name} · visualTags',
            initial: plan.characters[i].visualTags,
            maxLines: 2,
            enabled: !busy,
            onChanged: (v) => setState(() {
              final current = _plan;
              if (current == null) return;
              final list = [...current.characters];
              list[i] = list[i].copyWith(visualTags: v);
              _plan = current.copyWith(characters: list);
            }),
          ),
        ),
        AppPageGutter(
          child: AppOptionGroup<SpriteFacing>(
            label: '${plan.characters[i].name} · ${strings.visualStageFacing}',
            value: plan.characters[i].facing,
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
            onChanged: busy
                ? (_) {}
                : (facing) => setState(() {
                      final current = _plan;
                      if (current == null) return;
                      final list = [...current.characters];
                      final row = list[i];
                      list[i] = row.copyWith(
                        facing: facing,
                        portraitPrompt:
                            ComfyWorkflowTemplates.applyFacingToPortraitPrompt(
                          row.portraitPrompt,
                          facing,
                        ),
                      );
                      _plan = current.copyWith(characters: list);
                    }),
          ),
        ),
        AppPageGutter(
          child: _EditableBlock(
            key: ValueKey(
              'portrait-${plan.characters[i].characterId}-'
              '${plan.characters[i].facing.wireName}',
            ),
            label:
                '${plan.characters[i].name} · ${strings.visualStagePortrait}',
            initial: plan.characters[i].portraitPrompt,
            maxLines: 4,
            enabled: !busy,
            onChanged: (v) => setState(() {
              final current = _plan;
              if (current == null) return;
              final list = [...current.characters];
              list[i] = list[i].copyWith(portraitPrompt: v);
              _plan = current.copyWith(characters: list);
            }),
          ),
        ),
      ],
      for (var i = 0; i < plan.scenes.length; i++) ...[
        AppPageGutter(
          child: _EditableBlock(
            key: ValueKey('scene-${plan.scenes[i].nodeId}'),
            label: '${plan.scenes[i].title} · ${strings.visualStageScene}',
            initial: plan.scenes[i].scenePrompt,
            maxLines: 5,
            enabled: !busy,
            onChanged: (v) => setState(() {
              final current = _plan;
              if (current == null) return;
              final list = [...current.scenes];
              list[i] = list[i].copyWith(scenePrompt: v);
              _plan = current.copyWith(scenes: list);
            }),
          ),
        ),
      ],
    ];
  }
}

class _EditableBlock extends StatefulWidget {
  const _EditableBlock({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool enabled;

  @override
  State<_EditableBlock> createState() => _EditableBlockState();
}

class _EditableBlockState extends State<_EditableBlock> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.55,
        child: AppTextField(
          label: widget.label,
          controller: _controller,
          maxLines: widget.maxLines,
          minLines: widget.maxLines > 1 ? 2 : 1,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
