import 'dart:async';
import 'dart:math' as math;

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/app/project_change_watcher.dart';
import 'package:anoworld/create/world_book_editor_page.dart';
import 'package:anoworld/create/cast_editor_page.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/create/plot_elements_pick_page.dart';
import 'package:anoworld/data/project/project_cover_files.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:anoworld/domain/project/project_token_estimate.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_detail_entry.dart';
import 'package:anoworld/foundation/widgets/app_detail_section.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/home/create_assistant_story_scope.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/play/start_play.dart';
import 'package:anoworld/project/story_card_meta_page.dart';
import 'package:anoworld/project/story_cover_banner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Story overview: cover, structured sections, play actions, per-section edit.
class ProjectHubPage extends StatefulWidget {
  const ProjectHubPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectHubPage> createState() => _ProjectHubPageState();
}

class _ProjectHubPageState extends State<ProjectHubPage>
    with
        ProjectChangeWatcher<ProjectHubPage>,
        CreateAssistantStoryScope<ProjectHubPage> {
  @override
  String get assistantStoryId => widget.projectId;

  Project? _project;
  Object? _error;
  bool _loading = true;
  bool _loadScheduled = false;
  String? _projectDir;
  String? _coverAbsolutePath;

  /// 0 = hero expanded, 1 = title pinned in the overlay bar (NT-style).
  double _heroCollapse = 0;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final coverHeight =
        MediaQuery.sizeOf(context).height * StoryCoverBanner.restingHeightFraction;
    final range = math.max(
      1.0,
      coverHeight - AppTheme.pageTitleBarHeight,
    );
    final next = (_scroll.offset / range).clamp(0.0, 1.0);
    if ((next - _heroCollapse).abs() < 0.001) return;
    setState(() => _heroCollapse = next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadScheduled) return;
    _loadScheduled = true;
    _load();
  }

  @override
  String get watchedProjectId => widget.projectId;

  @override
  void reloadAfterExternalWrite() {
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_loading || _project != null || _error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final projects = AppScope.projectsOf(context);
      final project = await projects.open(widget.projectId);
      final dir = await projects.directoryFor(widget.projectId);
      final coverPath = await _resolveCoverPath(dir, project.meta.coverPath);
      if (!mounted) return;
      setState(() {
        _project = project;
        _projectDir = dir;
        _coverAbsolutePath = coverPath;
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

  Future<String?> _resolveCoverPath(
    String? projectDir,
    String? relative,
  ) async {
    if (projectDir == null) return null;
    final resolved = await ProjectCoverFiles.resolveExistingRelative(
      projectDir,
      relative,
    );
    if (resolved == null) return null;
    return ProjectCoverFiles.absolutePath(projectDir, resolved);
  }

  Future<void> _persist(Project project) async {
    final coverPath = project.meta.coverPath;
    final saved = await saveProjectMerged(
      AppScope.projectsOf(context),
      widget.projectId,
      (latest) => latest.copyWith(
        meta: latest.meta.copyWith(
          coverPath: coverPath,
          clearCoverPath: coverPath == null,
        ),
      ),
    );
    if (!mounted) return;
    final resolved = await _resolveCoverPath(_projectDir, saved.meta.coverPath);
    if (!mounted) return;
    setState(() {
      _project = saved;
      _coverAbsolutePath = resolved;
    });
  }

  Future<void> _changeCover() async {
    final project = _project;
    final dir = _projectDir;
    if (project == null) return;
    if (dir == null) {
      showAppToast(context, context.strings.cannotChangeCover);
      return;
    }

    final action = await showAppSheet<String>(
      context: context,
      size: AppSheetSize.compact,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                AppTheme.spaceSm,
              ),
              child: AppSectionHeader(context.strings.coverSection),
            ),
            AppListTile(
              title: context.strings.chooseImage,
              icon: Icons.image_outlined,
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (project.meta.coverPath != null || _coverAbsolutePath != null)
              AppListTile(
                title: context.strings.restoreDefault,
                icon: Icons.hide_image_outlined,
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
        );
      },
    );
    if (!mounted || action == null) return;

    if (action == 'clear') {
      await ProjectCoverFiles.deleteExisting(dir);
      await _persist(
        project.copyWith(meta: project.meta.copyWith(clearCoverPath: true)),
      );
      return;
    }

    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ProjectCoverFiles.allowedExtensions.toList(),
    );
    final path = picked?.path;
    if (path == null || path.isEmpty || !mounted) return;
    try {
      final relative = await ProjectCoverFiles.importFromPath(
        projectDir: dir,
        sourcePath: path,
      );
      if (!mounted) return;
      await _persist(
        project.copyWith(meta: project.meta.copyWith(coverPath: relative)),
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, context.strings.coverFailed(error));
    }
  }

  Future<void> _play() async {
    final project = _project;
    if (project == null) return;
    await startNewPlay(context, project);
  }

  Future<void> _openEditor(Widget page) async {
    await pushStoryRoute<void>(context, page);
    if (mounted) await _load();
  }

  Future<void> _openCreateHub() async {
    await pushStoryRoute<void>(
      context,
      CreateHubPage(projectId: widget.projectId),
    );
    if (mounted) await _load();
  }

  List<AppDetailEntry> _worldBookEntries(Project project) {
    final entries = project.worldBook.entries;
    if (entries.isEmpty) return const [];
    final always = entries.where((e) => e.alwaysOn);
    final keyed = entries.where((e) => !e.alwaysOn);
    return [...always, ...keyed]
        .map((entry) => _worldBookEntry(context, entry))
        .toList(growable: false);
  }

  static AppDetailEntry _worldBookEntry(
    BuildContext context,
    WorldBookEntry entry,
  ) {
    final title = entry.title.trim();
    return AppDetailEntry(
      title: title.isEmpty ? context.strings.unnamedEntry : title,
      tags: _worldBookTags(context, entry),
      body: entry.body.trim(),
    );
  }

  static List<String> _worldBookTags(
    BuildContext context,
    WorldBookEntry entry,
  ) {
    if (entry.alwaysOn) return <String>[context.strings.tagAlwaysOn];
    if (entry.keys.isEmpty) return <String>[context.strings.tagOnDemand];
    return entry.keys;
  }

  List<AppDetailEntry> _castEntries(Project project) {
    return project.cast
        .map((member) => _castEntry(context, member))
        .toList(growable: false);
  }

  static AppDetailEntry _castEntry(BuildContext context, CastMember member) {
    final strings = context.strings;
    final tags = <String>[
      if (member.isProtagonist) strings.tagProtagonist,
      if (member.exampleLines.isNotEmpty) strings.tagExampleLines,
    ];
    return AppDetailEntry(
      title: member.name.trim().isEmpty ? strings.unnamedCast : member.name.trim(),
      tags: tags,
      body: _castEntryBody(member),
    );
  }

  static String _castEntryBody(CastMember member) {
    final parts = <String>[
      if (member.summary.trim().isNotEmpty) member.summary.trim(),
      if (member.personality.trim().isNotEmpty) member.personality.trim(),
      if (member.speechStyle.trim().isNotEmpty) member.speechStyle.trim(),
    ];
    if (member.exampleLines.isNotEmpty) {
      parts.add(
        member.exampleLines
            .map((line) => '「${line.trim()}」')
            .where((line) => line != '「」')
            .join('\n'),
      );
    }
    return parts.join('\n\n');
  }

  List<AppDetailEntry> _mainEntries(Project project) {
    final main = project.main;
    final rows = <AppDetailEntry>[];
    final summary = main.summary.trim();
    if (summary.isNotEmpty) {
      rows.add(
        AppDetailEntry(
          title: context.strings.mainSummaryTitle,
          tags: <String>[context.strings.tagSummary],
          body: summary,
        ),
      );
    }
    for (final node in main.nodes) {
      rows.add(_mainNodeEntry(node));
    }
    return rows;
  }

  static AppDetailEntry _mainNodeEntry(StoryNode node) {
    final title = node.title.trim();
    final kind = StoryNodeKind.fromTags(node.tags);
    final extraTags = node.tags
        .where((t) => !StoryNodeKind.tagNames.contains(t))
        .toList(growable: false);
    return AppDetailEntry(
      title: title.isEmpty ? node.id : title,
      tags: <String>[kind.label, ...extraTags],
      body: node.synopsis?.trim() ?? '',
    );
  }

  String _mainEmptyHint(BuildContext context, Project project) {
    final nodes = project.main.nodes.length;
    final edges = project.main.edges.length;
    if (nodes == 0) return context.strings.noMainStations;
    return context.strings.mainStops(nodes, edges);
  }

  /// Size lines sit under the section title; empty sections keep their hint.
  String? _worldBookSize(Project project, ProjectTokenEstimate? size) {
    if (size == null || project.worldBook.entries.isEmpty) return null;
    return context.strings.worldBookSize(
      project.worldBook.entries.length,
      project.worldBook.entries.where((e) => e.alwaysOn).length,
      size.worldBook,
    );
  }

  String? _castSize(Project project, ProjectTokenEstimate? size) {
    if (size == null || project.cast.isEmpty) return null;
    return context.strings.castSize(project.cast.length, size.cast);
  }

  String? _mainSize(Project project, ProjectTokenEstimate? size) {
    if (size == null || project.main.nodes.isEmpty) return null;
    return context.strings.mainSize(project.main.nodes.length, size.main);
  }

  String? _plotElementsSize(
    Project project,
    ProjectTokenEstimate? size,
    PlotElementCatalog catalog,
  ) {
    if (size == null) return null;
    final selected =
        catalog.resolveSelected(project.plotElements.selectedIds).length;
    if (selected == 0) return null;
    return context.strings.plotElementsSize(selected, size.plotElements);
  }
  /// Card author / version / tags / notes carried over from a card import.
  List<AppDetailEntry> _cardInfoEntries(Project project) {
    final strings = context.strings;
    final card = project.meta.card;
    return <AppDetailEntry>[
      if (card.creator.trim().isNotEmpty)
        AppDetailEntry(
          title: strings.cardInfoCreator,
          body: card.creator.trim(),
        ),
      if (card.version.trim().isNotEmpty)
        AppDetailEntry(
          title: strings.cardInfoVersion,
          body: card.version.trim(),
        ),
      if (card.tags.isNotEmpty)
        AppDetailEntry(title: strings.cardInfoTags, tags: card.tags, body: ''),
      if (card.creatorNotes.trim().isNotEmpty)
        AppDetailEntry(
          title: strings.cardInfoCreatorNotes,
          body: card.creatorNotes.trim(),
        ),
    ];
  }

  List<AppDetailEntry> _plotElementEntries(Project project) {
    final catalog = AppScope.settingsOf(context).plotElements;
    final rows = catalog.resolveSelected(project.plotElements.selectedIds);
    return rows
        .map(
          (e) => AppDetailEntry(
            title: e.keyword.trim().isEmpty
                ? context.strings.unnamed
                : e.keyword.trim(),
            tags: catalog.isBuiltInId(e.id)
                ? <String>[context.strings.builtInTag]
                : const <String>[],
            body: e.clippedDescription,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final catalog = AppScope.settingsOf(context).plotElements;
    final size = project == null
        ? null
        : ProjectTokenEstimate.of(project, plotCatalog: catalog);
    final title = project?.meta.title.trim().isEmpty == true ||
            project == null
        ? context.strings.untitledStory
        : project.meta.title;

    final ready = project != null && !_loading && _error == null;
    // Match NT: cross-fade once the bar is mostly pinned.
    final pinnedFade = const Interval(
      0.55,
      1,
      curve: Curves.easeInOut,
    ).transform(_heroCollapse);
    final expandedTitleOpacity = 1.0 - pinnedFade;
    final collapsedTitleOpacity = pinnedFade;
    final expandedTitleScale = 1.0 - (0.12 * _heroCollapse);
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      title: title,
      overlayTitle: ready,
      overlayTitleFill: ready
          ? scheme.surface.withValues(alpha: 0.92 * pinnedFade)
          : null,
      titleWidget: ready
          ? Opacity(
              opacity: collapsedTitleOpacity,
              child: AppText(
                title,
                role: AppTextRole.subtitle,
                maxLines: 1,
              ),
            )
          : null,
      onBack: () => Navigator.of(context).maybePop(),
      actions: ready
          ? [
              AppCircleButton(
                icon: Icons.photo_outlined,
                tooltip: context.strings.changeCover,
                onPressed: _changeCover,
              ),
              AppCircleButton(
                icon: Icons.edit_note_outlined,
                tooltip: context.strings.continueCreating,
                onPressed: _openCreateHub,
              ),
            ]
          : const [],
      floatingActionButton: ready
          ? SizedBox.square(
              dimension: AppCircleButton.fabDiameter,
              child: AppCircleButton.fab(
                icon: Icons.play_arrow_rounded,
                tooltip: context.strings.startPlaying,
                onPressed: _play,
              ),
            )
          : null,
      body: !ready
          ? AppPageBody(
              padding: const EdgeInsets.only(
                top: AppTheme.pagePadding,
                bottom: AppTheme.pagePadding,
              ),
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
                  ),
              ],
            )
          : CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: StoryCoverBanner(
                    coverPath: _coverAbsolutePath,
                    title: title,
                    titleOpacity: expandedTitleOpacity,
                    titleScale: expandedTitleScale,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: AppTheme.spaceLg,
                    bottom: AppTheme.pagePadding +
                        MediaQuery.paddingOf(context).bottom +
                        AppCircleButton.fabDiameter +
                        AppTheme.spaceLg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        AppDetailSection(
                          title: context.strings.worldBookTitle,
                          icon: Icons.public_outlined,
                          subtitle: _worldBookSize(project!, size),
                          entries: _worldBookEntries(project),
                          emptyHint: context.strings.worldBookEmpty,
                          onEdit: () => _openEditor(
                            WorldBookEditorPage(projectId: widget.projectId),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        AppDetailSection(
                          title: context.strings.castTitle,
                          icon: Icons.groups_outlined,
                          subtitle: _castSize(project, size),
                          entries: _castEntries(project),
                          emptyHint: context.strings.castEmpty,
                          onEdit: () => _openEditor(
                            CastEditorPage(projectId: widget.projectId),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        AppDetailSection(
                          title: context.strings.mainTitle,
                          icon: Icons.account_tree_outlined,
                          subtitle: _mainSize(project, size),
                          entries: _mainEntries(project),
                          emptyHint: _mainEmptyHint(context, project),
                          onEdit: () => _openEditor(
                            MainGraphPage(projectId: widget.projectId),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        AppDetailSection(
                          title: context.strings.plotElementsTitle,
                          icon: Icons.theater_comedy_outlined,
                          subtitle: _plotElementsSize(project, size, catalog),
                          entries: _plotElementEntries(project),
                          emptyHint: context.strings.plotElementsEmpty,
                          onEdit: () => _openEditor(
                            PlotElementsPickPage(projectId: widget.projectId),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        AppDetailSection(
                          title: context.strings.cardInfoTitle,
                          icon: Icons.badge_outlined,
                          entries: _cardInfoEntries(project),
                          emptyHint: context.strings.cardInfoEmpty,
                          onEdit: () => _openEditor(
                            StoryCardMetaPage(projectId: widget.projectId),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}