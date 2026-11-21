import 'dart:async';
import 'dart:io';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/project_change_watcher.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/visual_asset_preview.dart';
import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/domain/ai/visual/visual_image_pipeline.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/l10n/app_localizations.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/home/create_assistant_story_scope.dart';
import 'package:flutter/material.dart';

/// Edit cast members for a project.
class CastEditorPage extends StatefulWidget {
  const CastEditorPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<CastEditorPage> createState() => _CastEditorPageState();
}

class _CastEditorPageState extends State<CastEditorPage>
    with
        ProjectChangeWatcher<CastEditorPage>,
        CreateAssistantStoryScope<CastEditorPage> {
  @override
  String get assistantStoryId => widget.projectId;

  Project? _project;
  String? _projectDir;
  Object? _error;
  bool _loading = true;
  Timer? _saveDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null && _loading) {
      _load();
    }
  }

  @override
  String get watchedProjectId => widget.projectId;

  /// Cast written elsewhere (create assistant): show the saved members.
  @override
  void reloadAfterExternalWrite() {
    unawaited(_load());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
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

  Future<void> _persist(Project project) async {
    final cast = project.cast;
    final assets = project.assets;
    final saved = await saveProjectMerged(
      AppScope.projectsOf(context),
      widget.projectId,
      (latest) => latest.copyWith(cast: cast, assets: assets),
    );
    if (!mounted) return;
    setState(() => _project = saved);
  }

  void _scheduleSave(List<CastMember> cast) {
    final current = _project;
    if (current == null) return;
    final next = current.copyWith(cast: List.unmodifiable(cast));
    setState(() => _project = next);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      await _persist(next);
    });
  }

  String _subtitle(AppStrings strings, CastMember member) {
    if (member.summary.trim().isNotEmpty) return member.summary.trim();
    if (member.personality.trim().isNotEmpty) return member.personality.trim();
    return strings.castNoSummary;
  }

  File? _avatarFile(CastMember member) {
    final dir = _projectDir;
    final project = _project;
    final assetId = member.avatarAssetId?.trim();
    if (dir == null || project == null || assetId == null || assetId.isEmpty) {
      return null;
    }
    return ProjectAssetFiles.tryFile(
      projectDir: dir,
      asset: project.assetById(assetId),
    );
  }

  Widget _avatarLeading(CastMember member) {
    final file = _avatarFile(member);
    final scheme = Theme.of(context).colorScheme;
    const size = 40.0;
    if (file == null) {
      return Icon(
        member.isProtagonist ? Icons.star_outline : Icons.person_outline,
        size: AppListTile.iconSize,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.spaceXs),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Image.file(
          file,
          key: ValueKey(
            '${file.path}-${file.lastModifiedSync().millisecondsSinceEpoch}',
          ),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            member.isProtagonist ? Icons.star_outline : Icons.person_outline,
            size: AppListTile.iconSize,
          ),
        ),
      ),
    );
  }

  Future<void> _editMember({CastMember? existing}) async {
    final project = _project;
    if (project == null) return;
    final draft = existing ??
        CastMember(
          id: newEntityId('c'),
          name: '',
        );
    final defaultProtagonist = draft.isProtagonist ||
        (existing == null &&
            project.cast.isEmpty &&
            !project.cast.any((c) => c.isProtagonist));

    final result = await showAppSheet<_CastSheetResult>(
      context: context,
      size: AppSheetSize.half,
      builder: (_) => _CastMemberSheet(
        draft: draft,
        existing: existing,
        defaultProtagonist: defaultProtagonist,
        projectId: widget.projectId,
        projectDir: _projectDir,
        avatarFile: _avatarFile(draft),
        onProjectUpdated: (next) {
          if (!mounted) return;
          setState(() => _project = next);
        },
      ),
    );

    if (result == null || !mounted) return;

    var cast = [...(_project ?? project).cast];
    if (result.delete) {
      cast.removeWhere((c) => c.id == draft.id);
    } else {
      final saved = result.member!;
      final index = cast.indexWhere((c) => c.id == draft.id);
      if (index < 0) {
        cast.add(saved);
      } else {
        cast[index] = saved;
      }
      cast = castWithProtagonist(
        cast,
        memberId: saved.id,
        isProtagonist: saved.isProtagonist,
      );
    }
    _scheduleSave(cast);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ui = context.ui;
    final project = _project;
    final cast = project?.cast ?? const <CastMember>[];
    return AppPage(
      title: strings.castTitle,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppCircleButton(
          icon: Icons.add,
          tooltip: strings.castAddMember,
          onPressed: _loading || _error != null ? null : () => _editMember(),
        ),
      ],
      body: AppPageBody.list(
        children: [
          if (_loading)
            AppPageGutter(
              child: AppText(ui.loading, role: AppTextRole.caption),
            )
          else if (_error != null)
            AppPageGutter(
              child: AppEmptyState(
                message: strings.castOpenFailed,
                detail: _error.toString(),
                action: AppButton(
                  label: ui.retry,
                  onPressed: _load,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            )
          else if (project != null) ...[
            AppSectionHeader(
              strings.castSection,
              subtitle: strings.castSectionHint,
              gutter: true,
            ),
            if (cast.isEmpty)
              AppPageGutter(
                child: AppEmptyState(
                  message: strings.castEmpty,
                  detail: strings.castEmptyDetail,
                  action: AppButton(
                    label: strings.castAddOne,
                    onPressed: () => _editMember(),
                    variant: AppButtonVariant.secondary,
                  ),
                ),
              )
            else
              AppListTileStack(
                tiles: [
                  for (final member in cast)
                    AppListTile(
                      title: member.name,
                      subtitle: member.isProtagonist
                          ? strings.castProtagonist(_subtitle(strings, member))
                          : _subtitle(strings, member),
                      leading: _avatarLeading(member),
                      trailing: const AppForwardIcon(),
                      onTap: () => _editMember(existing: member),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _CastSheetResult {
  const _CastSheetResult.save(this.member) : delete = false;
  const _CastSheetResult.delete()
      : member = null,
        delete = true;

  final CastMember? member;
  final bool delete;
}

class _CastMemberSheet extends StatefulWidget {
  const _CastMemberSheet({
    required this.draft,
    required this.existing,
    required this.defaultProtagonist,
    required this.projectId,
    required this.projectDir,
    required this.avatarFile,
    required this.onProjectUpdated,
  });

  final CastMember draft;
  final CastMember? existing;
  final bool defaultProtagonist;
  final String projectId;
  final String? projectDir;
  final File? avatarFile;
  final ValueChanged<Project> onProjectUpdated;

  @override
  State<_CastMemberSheet> createState() => _CastMemberSheetState();
}

class _CastMemberSheetState extends State<_CastMemberSheet> {
  late final TextEditingController _name;
  late final TextEditingController _summary;
  late final TextEditingController _personality;
  late final TextEditingController _speech;
  late final TextEditingController _examples;
  late final CastMember _baseline;
  late bool _isProtagonist;
  late String? _avatarAssetId;
  File? _avatarFile;
  bool _regenBusy = false;

  @override
  void initState() {
    super.initState();
    _baseline = widget.draft.copyWith(isProtagonist: widget.defaultProtagonist);
    _name = TextEditingController(text: widget.draft.name);
    _summary = TextEditingController(text: widget.draft.summary);
    _personality = TextEditingController(text: widget.draft.personality);
    _speech = TextEditingController(text: widget.draft.speechStyle);
    _examples = TextEditingController(text: widget.draft.exampleLines.join('\n'));
    _isProtagonist = widget.defaultProtagonist;
    _avatarAssetId = widget.draft.avatarAssetId;
    _avatarFile = widget.avatarFile;
    for (final c in [_name, _summary, _personality, _speech, _examples]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _summary, _personality, _speech, _examples]) {
      c.removeListener(_markDirty);
    }
    _name.dispose();
    _summary.dispose();
    _personality.dispose();
    _speech.dispose();
    _examples.dispose();
    super.dispose();
  }

  CastMember _snapshot() {
    final nextName = _name.text.trim();
    return widget.draft.copyWith(
      name: nextName,
      summary: _summary.text.trim(),
      personality: _personality.text.trim(),
      speechStyle: _speech.text.trim(),
      exampleLines: _examples.text
          .split(RegExp(r'[\r\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false),
      isProtagonist: _isProtagonist,
      avatarAssetId: _avatarAssetId,
    );
  }

  bool get _isDirty => !_membersEqual(_snapshot(), _baseline);

  static bool _membersEqual(CastMember a, CastMember b) {
    return a.name == b.name &&
        a.summary == b.summary &&
        a.personality == b.personality &&
        a.speechStyle == b.speechStyle &&
        a.isProtagonist == b.isProtagonist &&
        a.avatarAssetId == b.avatarAssetId &&
        _listEqual(a.exampleLines, b.exampleLines);
  }

  static bool _listEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _regenPortrait() async {
    final strings = context.strings;
    final dir = widget.projectDir;
    if (dir == null || dir.isEmpty) {
      showAppToast(context, strings.visualNeedComfyShort);
      return;
    }
    if (VisualImagePipeline.defaultPortraitPrompt(_snapshot()).isEmpty &&
        widget.draft.visualTags.trim().isEmpty) {
      showAppToast(context, strings.visualNeedPortraitTags);
      return;
    }
    final image = AppScope.settingsOf(context).ai.image;
    if (image.kind != AiImageProviderKind.comfyui || !image.isConfigured) {
      showAppToast(context, strings.visualNeedComfyShort);
      return;
    }
    final projects = AppScope.projectsOf(context);
    final changes = AppScope.projectChangesOf(context);
    setState(() => _regenBusy = true);
    try {
      final project = await projects.open(widget.projectId);
      final pipeline = VisualImagePipeline();
      final next = await pipeline.regenerateAvatar(
        project: project,
        projectDir: dir,
        image: image,
        characterId: widget.draft.id,
      );
      await projects.save(next);
      changes.markChanged(widget.projectId);
      if (!mounted) return;
      final member = next.castById(widget.draft.id);
      final assetId = member?.avatarAssetId;
      final file = assetId == null
          ? null
          : ProjectAssetFiles.tryFile(
              projectDir: dir,
              asset: next.assetById(assetId),
            );
      widget.onProjectUpdated(next);
      setState(() {
        _avatarAssetId = assetId;
        _avatarFile = file;
        _regenBusy = false;
      });
      showAppToast(context, strings.visualRegenDone);
    } on VisualImageException catch (error) {
      if (!mounted) return;
      setState(() => _regenBusy = false);
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _regenBusy = false);
      showAppToast(context, error.toString());
    }
  }

  void _save() {
    final next = _snapshot();
    Navigator.of(context).pop(
      _CastSheetResult.save(
        next.copyWith(
          name: next.name.isEmpty
              ? context.strings.castUnnamedMember
              : next.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final existing = widget.existing;
    return AppSheetEditForm(
      title: existing == null
          ? strings.castNewMember
          : strings.castEditMember,
      isDirty: _isDirty,
      onSave: _save,
      body: AppSheetScrollBody(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          0,
          AppTheme.pagePadding,
          AppTheme.spaceMd,
        ),
        children: [
          if (existing != null) ...[
            VisualAssetPreview(
              file: _avatarFile,
              emptyLabel: strings.visualNoPortrait,
              height: 180,
              fit: BoxFit.contain,
              busy: _regenBusy,
              actionLabel: strings.visualRegenPortrait,
              onAction: _regenBusy ? null : _regenPortrait,
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          AppTextField(
            label: strings.castNameLabel,
            controller: _name,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.castSummaryLabel,
            controller: _summary,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.castPersonalityLabel,
            controller: _personality,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.castSpeechLabel,
            controller: _speech,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.castExamplesLabel,
            controller: _examples,
            minLines: 3,
            maxLines: 6,
            hint: strings.castExamplesHint,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppListTile(
            title: strings.castProtagonistLabel,
            subtitle: strings.castProtagonistHint,
            icon: Icons.star_outline,
            trailing: AppSwitch(
              value: _isProtagonist,
              onChanged: (value) => setState(() => _isProtagonist = value),
            ),
          ),
          if (existing != null) ...[
            const SizedBox(height: AppTheme.spaceLg),
            AppButton(
              label: strings.castDeleteMember,
              expanded: true,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(
                const _CastSheetResult.delete(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
