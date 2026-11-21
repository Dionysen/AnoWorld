import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/project_change_watcher.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/world_book_editor_page.dart';
import 'package:anoworld/create/cast_editor_page.dart';
import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/create/plot_elements_pick_page.dart';
import 'package:anoworld/create/visual_stage_page.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_token_estimate.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_prompt_dialog.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/home/create_assistant_story_scope.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:flutter/material.dart';

/// Creation cross-section: pick WorldBook / Cast / Main to edit.
class CreateHubPage extends StatefulWidget {
  const CreateHubPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<CreateHubPage> createState() => _CreateHubPageState();
}

class _CreateHubPageState extends State<CreateHubPage>
    with
        ProjectChangeWatcher<CreateHubPage>,
        CreateAssistantStoryScope<CreateHubPage> {
  @override
  String get assistantStoryId => widget.projectId;

  Project? _project;
  Object? _error;
  bool _loading = true;
  bool _loadScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadScheduled) return;
    _loadScheduled = true;
    _load();
  }

  @override
  String get watchedProjectId => widget.projectId;

  /// Layers written elsewhere (create assistant): refresh the size counts.
  @override
  void reloadAfterExternalWrite() {
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

  Future<void> _open(Widget page) async {
    await pushStoryRoute<void>(context, page);
    if (mounted) await _load();
  }

  Future<void> _renameStory() async {
    final project = _project;
    if (project == null) return;
    final strings = context.strings;
    final name = await showAppPromptDialog(
      context,
      title: strings.renameStory,
      label: strings.nameLabel,
      initial: project.meta.title,
      hint: strings.storyNameHint,
    );
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == project.meta.title) return;
    final projects = AppScope.projectsOf(context);
    final changes = AppScope.projectChangesOf(context);
    try {
      final next = project.copyWith(
        meta: project.meta.copyWith(title: trimmed),
      );
      await projects.save(next);
      if (!mounted) return;
      changes.markChanged(widget.projectId);
      AppLog.instance.info('改故事名：$trimmed', tag: 'create.hub');
      setState(() => _project = next);
    } catch (error, stack) {
      AppLog.instance.error(
        '改故事名失败',
        tag: 'create.hub',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      showAppToast(context, strings.renameStoryFailed(error));
    }
  }

  String _worldBookSubtitle(
    BuildContext context,
    Project project,
    ProjectTokenEstimate size,
  ) {
    return context.strings.worldBookSize(
      project.worldBook.entries.length,
      project.worldBook.entries.where((e) => e.alwaysOn).length,
      size.worldBook,
    );
  }

  String _castSubtitle(
    BuildContext context,
    Project project,
    ProjectTokenEstimate size,
  ) {
    return context.strings.castSize(project.cast.length, size.cast);
  }

  String _mainSubtitle(
    BuildContext context,
    Project project,
    ProjectTokenEstimate size,
  ) {
    return context.strings.mainSize(project.main.nodes.length, size.main);
  }

  String _plotElementsSubtitle(
    BuildContext context,
    Project project,
    ProjectTokenEstimate size,
    PlotElementCatalog catalog,
  ) {
    return context.strings.plotElementsSize(
      catalog.resolveSelected(project.plotElements.selectedIds).length,
      size.plotElements,
    );
  }

  String _pageTitle(BuildContext context, Project? project) {
    final name = project?.meta.title.trim();
    if (name == null || name.isEmpty) return context.strings.createHubUntitled;
    return context.strings.createHubTitle(name);
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final catalog = AppScope.settingsOf(context).plotElements;
    final size = project == null
        ? null
        : ProjectTokenEstimate.of(project, plotCatalog: catalog);
    final ready = project != null && !_loading && _error == null;
    return AppPage(
      title: _pageTitle(context, project),
      onBack: () => Navigator.of(context).maybePop(),
      actions: ready
          ? [
              AppCircleButton(
                icon: Icons.drive_file_rename_outline,
                tooltip: context.strings.renameStory,
                onPressed: _renameStory,
              ),
            ]
          : const [],
      body: AppPageBody.list(
        children: [
          if (_loading)
            AppPageGutter(
              child: AppText(
                context.strings.loading,
                role: AppTextRole.caption,
              ),
            )
          else if (_error != null)
            AppPageGutter(
              child: AppEmptyState(
                message: context.strings.openStoryFailed,
                detail: _error.toString(),
                action: AppButton(
                  label: context.strings.retry,
                  onPressed: _load,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            )
          else if (project != null && size != null)
            AppListTileStack(
              tiles: [
                AppListTile(
                  title: context.strings.worldBookTitle,
                  subtitle: _worldBookSubtitle(context, project, size),
                  icon: Icons.public_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    WorldBookEditorPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: context.strings.castTitle,
                  subtitle: _castSubtitle(context, project, size),
                  icon: Icons.groups_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    CastEditorPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: context.strings.mainTitle,
                  subtitle: _mainSubtitle(context, project, size),
                  icon: Icons.account_tree_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    MainGraphPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: context.strings.plotElementsTitle,
                  subtitle: _plotElementsSubtitle(
                    context,
                    project,
                    size,
                    catalog,
                  ),
                  icon: Icons.theater_comedy_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    PlotElementsPickPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: context.strings.visualStageTitle,
                  subtitle: context.strings.visualStageSubtitle,
                  icon: Icons.image_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    VisualStagePage(projectId: widget.projectId),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
