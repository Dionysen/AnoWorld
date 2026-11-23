import 'dart:async';
import 'dart:typed_data';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/create_entry_page.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/project/project_cover_files.dart';
import 'package:anoworld/data/project/project_package_archive.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_folder.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_detail_pane.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_master_detail.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_prompt_dialog.dart';
import 'package:anoworld/foundation/widgets/app_search_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:anoworld/home/home_tab_back.dart';
import 'package:anoworld/home/library_browse_views.dart';
import 'package:anoworld/home/library_display_labels.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:anoworld/play/start_play.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class WorksTab extends StatefulWidget {
  const WorksTab({
    super.key,
    required this.selection,
    this.pickImportDirectory,
    this.pickImportPackage,
    this.onChromeChanged,
    this.onBrowsePathChanged,
  });

  final LibrarySelectionController selection;
  final Future<String?> Function()? pickImportDirectory;
  final Future<Uint8List?> Function()? pickImportPackage;

  /// Home chrome (back handling / assistant) may need a rebuild.
  final VoidCallback? onChromeChanged;
  final ValueChanged<List<String>>? onBrowsePathChanged;

  @override
  State<WorksTab> createState() => WorksTabState();
}

class WorksTabState extends State<WorksTab> implements HomeTabBack {
  final _searchController = TextEditingController();
  final List<String> _browsePath = <String>[];
  bool _folderEnterForward = true;
  String _query = '';
  Timer? _searchDebounce;
  bool _loading = true;
  String? _status;
  List<ProjectSummary> _allProjects = const [];
  List<ProjectFolder> _folders = const [];
  List<ProjectFolder> _breadcrumbs = const [];
  Map<String, String?> _membership = const {};
  Map<String, String> _covers = const {};

  /// Story shown in the wide-window detail pane; null shows the empty hint.
  String? _selectedProjectId;

  /// Whether the last layout rendered list | detail, so taps and
  /// [revealProject] agree with what is on screen.
  bool _rendersSplit = false;

  /// Stack of the detail column (story page, then whatever it opens).
  final _detailPane = AppDetailPaneController();

  List<String> get browsePath => List<String>.unmodifiable(_browsePath);

  String? get browseFolderId =>
      _browsePath.isEmpty ? null : _browsePath.last;

  bool get folderEnterForward => _folderEnterForward;

  LibraryDisplayController? _display;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_onSelectionChanged);
    _detailPane.addListener(_onDetailPaneChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _display = AppScope.libraryDisplayOf(context);
      _display!.addListener(_onDisplayChanged);
      reload();
    });
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChanged);
    _detailPane
      ..removeListener(_onDetailPaneChanged)
      ..dispose();
    _display?.removeListener(_onDisplayChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// The pane opened / closed a page, so the shell's back state changed.
  void _onDetailPaneChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onChromeChanged?.call();
  }

  void _onSelectionChanged() {
    widget.onChromeChanged?.call();
    setState(() {});
  }

  void _onDisplayChanged() => setState(() {});

  void _applyBrowsePath(List<String> next, {required bool forward}) {
    _folderEnterForward = forward;
    _browsePath
      ..clear()
      ..addAll(next);
    widget.onBrowsePathChanged?.call(browsePath);
  }

  Future<void> openFolder(String folderId) async {
    widget.selection.exit();
    await _navigateBrowse([..._browsePath, folderId], forward: true);
  }

  Future<void> jumpBreadcrumb(int index) async {
    widget.selection.exit();
    final next = index < 0
        ? const <String>[]
        : _browsePath.take(index + 1).toList(growable: false);
    await _navigateBrowse(next, forward: false);
  }

  /// Selects [projectId], entering its folder when needed.
  ///
  /// The sessions tab routes 「打开故事」 here, so a story page only ever opens
  /// in the stories tab: in the detail column when the window is wide, as a
  /// pushed page when it is narrow.
  Future<void> revealProject(String projectId) async {
    widget.selection.exit();
    final folders = AppScope.foldersOf(context);
    final folderId = await folders.folderIdForProject(projectId);
    if (!mounted) return;
    final crumbs = folderId == null
        ? const <ProjectFolder>[]
        : await folders.breadcrumbs(folderId);
    if (!mounted) return;
    final next = crumbs.map((folder) => folder.id).toList(growable: false);
    if (!_samePath(next, _browsePath)) {
      await _navigateBrowse(next, forward: true);
      if (!mounted) return;
    }
    if (!_rendersSplit) {
      await _openRoute(ProjectHubPage(projectId: projectId));
      return;
    }
    setState(() => _selectedProjectId = projectId);
    widget.onChromeChanged?.call();
  }

  static bool _samePath(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool get canGoBack =>
      _detailPane.canPop ||
      widget.selection.selectionMode ||
      _selectedProjectId != null ||
      _browsePath.isNotEmpty;

  @override
  bool handleSystemBack() {
    if (_detailPane.pop()) return true;
    if (widget.selection.selectionMode) {
      widget.selection.exit();
      return true;
    }
    if (_selectedProjectId != null) {
      setState(() => _selectedProjectId = null);
      return true;
    }
    if (_browsePath.isNotEmpty) {
      jumpBreadcrumb(_browsePath.length - 2);
      return true;
    }
    return false;
  }

  /// Folder enter/exit: fetch first, then swap path + data in one frame so
  /// [AnimatedSwitcher] can slide instead of being replaced by a loading flash.
  Future<void> _navigateBrowse(
    List<String> next, {
    required bool forward,
  }) async {
    final folderId = next.isEmpty ? null : next.last;
    try {
      final snap = await _fetchBrowse(folderId);
      if (!mounted) return;
      setState(() {
        _applyBrowsePath(next, forward: forward);
        _allProjects = snap.projects;
        _folders = snap.folders;
        _breadcrumbs = snap.breadcrumbs;
        _membership = snap.membership;
        _covers = snap.covers;
        _loading = false;
        _status = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = context.strings.loadFailed(error));
    }
  }

  Future<({
    List<ProjectSummary> projects,
    List<ProjectFolder> folders,
    List<ProjectFolder> breadcrumbs,
    Map<String, String?> membership,
    Map<String, String> covers,
  })> _fetchBrowse(String? folderId) async {
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    final all = await projects.listProjects();
    final listed = await folders.listFolders(parentId: folderId);
    final crumbs = folderId == null
        ? const <ProjectFolder>[]
        : await folders.breadcrumbs(folderId);
    final membership = <String, String?>{};
    final covers = <String, String>{};
    for (final project in all) {
      membership[project.id] = await folders.folderIdForProject(project.id);
      final relative = project.coverPath;
      if (relative != null && relative.isNotEmpty) {
        covers[project.id] = ProjectCoverFiles.absolutePath(
          project.directoryPath,
          relative,
        );
      }
    }
    return (
      projects: all,
      folders: listed,
      breadcrumbs: crumbs,
      membership: membership,
      covers: covers,
    );
  }

  Future<void> reload() async {
    final blockList = _loading || _allProjects.isEmpty;
    if (blockList) {
      setState(() {
        _loading = true;
        _status = null;
      });
    }
    try {
      final snap = await _fetchBrowse(browseFolderId);
      if (!mounted) return;
      setState(() {
        _allProjects = snap.projects;
        _folders = snap.folders;
        _breadcrumbs = snap.breadcrumbs;
        _membership = snap.membership;
        _covers = snap.covers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = context.strings.loadFailed(error);
      });
    }
  }

  List<ProjectSummary> get _visibleProjects {
    final folderId = browseFolderId;
    final q = _query.trim().toLowerCase();
    return _allProjects.where((project) {
      final memberOf = _membership[project.id];
      if (memberOf != folderId) return false;
      if (q.isEmpty) return true;
      return project.title.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  List<ProjectFolder> get _visibleFolders {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _folders;
    return _folders
        .where((f) => f.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _openRoute(Widget page) async {
    await pushStoryRoute<void>(context, page);
    if (mounted) await reload();
  }

  /// Wide windows select in the detail pane; narrow ones push the full page.
  Future<void> _openProject(
    ProjectSummary project, {
    required bool split,
  }) async {
    widget.selection.exit();
    if (split) {
      setState(() => _selectedProjectId = project.id);
      widget.onChromeChanged?.call();
      AppLog.instance.info('选中故事：${project.title}', tag: 'works.story');
      return;
    }
    AppLog.instance.info('查看故事：${project.title}', tag: 'works.story');
    await _openRoute(ProjectHubPage(projectId: project.id));
  }

  Future<void> createBlank() async {
    widget.selection.exit();
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    final folderId = browseFolderId;
    try {
      final project = await projects.create(
        title: context.strings.untitledStory,
      );
      if (folderId != null) {
        await folders.moveProjects(
          projectIds: [project.meta.id],
          folderId: folderId,
        );
      }
      if (!mounted) return;
      await _openRoute(ProjectHubPage(projectId: project.meta.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = context.strings.createFailed(error));
    }
  }

  Future<void> addSample() async {
    widget.selection.exit();
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    final folderId = browseFolderId;
    try {
      final existing = await projects.listProjects();
      for (final row in existing) {
        if (row.id == 'proj_rain_night') {
          if (!mounted) return;
          await _openRoute(const ProjectHubPage(projectId: 'proj_rain_night'));
          return;
        }
      }
      final sample = const ProjectFactory().createRainNightSample();
      await projects.save(sample);
      if (folderId != null) {
        await folders.moveProjects(
          projectIds: [sample.meta.id],
          folderId: folderId,
        );
      }
      if (!mounted) return;
      await _openRoute(ProjectHubPage(projectId: sample.meta.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = context.strings.sampleWriteFailed(error));
    }
  }

  Future<void> importPack() async {
    widget.selection.exit();
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    final folderId = browseFolderId;
    try {
      final Project project;
      if (widget.pickImportDirectory != null) {
        final path = await widget.pickImportDirectory!();
        if (!mounted) return;
        if (path == null || path.isEmpty) return;
        project = await projects.importFromDirectory(path);
      } else {
        final picker = widget.pickImportPackage ?? _defaultPickPackage;
        final bytes = await picker();
        if (!mounted) return;
        if (bytes == null || bytes.isEmpty) return;
        project = await projects.importFromPackageBytes(bytes);
      }
      if (folderId != null) {
        await folders.moveProjects(
          projectIds: [project.meta.id],
          folderId: folderId,
        );
      }
      if (!mounted) return;
      AppLog.instance.info('导入故事包：${project.meta.title}', tag: 'works.pack');
      setState(
        () => _status = context.strings.importedStory(project.meta.title),
      );
      await _openRoute(ProjectHubPage(projectId: project.meta.id));
    } on ProjectIoException catch (error, stack) {
      AppLog.instance.error(
        '导入故事包失败',
        tag: 'works.pack',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (error, stack) {
      AppLog.instance.error(
        '导入故事包失败',
        tag: 'works.pack',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _status = context.strings.importFailed(error));
    }
  }

  Future<Uint8List?> _defaultPickPackage() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: context.strings.pickStoryPackTitle,
      type: FileType.custom,
      allowedExtensions: const [
        ProjectPackageArchive.fileExtension,
        'zip',
      ],
    );
    if (picked.isEmpty) return null;
    return picked.single.readAsBytes();
  }

  Future<void> exportPack(ProjectSummary summary) async {
    widget.selection.exit();
    final projects = AppScope.projectsOf(context);
    try {
      final project = await projects.open(summary.id);
      final bytes = await projects.exportPackageBytes(project: project);
      if (!mounted) return;
      final fileName =
          '${_safeExportName(project.meta.title)}.${ProjectPackageArchive.fileExtension}';
      final saved = await FilePicker.saveFile(
        dialogTitle: context.strings.exportStoryPackDialog,
        fileName: fileName,
        bytes: bytes,
      );
      if (!mounted) return;
      if (saved == null) return;
      AppLog.instance.info('导出故事包：${project.meta.title}', tag: 'works.pack');
      setState(
        () => _status = context.strings.exportedStory(project.meta.title),
      );
    } on ProjectIoException catch (error, stack) {
      AppLog.instance.error(
        '导出故事包失败',
        tag: 'works.pack',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (error, stack) {
      AppLog.instance.error(
        '导出故事包失败',
        tag: 'works.pack',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _status = context.strings.exportFailed(error));
    }
  }

  String _safeExportName(String title) {
    final cleaned = title
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'story';
    return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  }

  Future<void> openCreateEntry(CreateEntryKind kind) {
    widget.selection.exit();
    return _openRoute(CreateEntryPage(kind: kind));
  }

  Future<String?> _promptFolderName({
    required String title,
    String initial = '',
  }) {
    return showAppPromptDialog(
      context,
      title: title,
      label: context.strings.nameLabel,
      initial: initial,
      hint: context.strings.folderNameHint,
    );
  }

  Future<void> createFolder() async {
    widget.selection.exit();
    final name = await _promptFolderName(title: context.strings.newFolder);
    if (name == null || !mounted) return;
    try {
      await AppScope.foldersOf(context).createFolder(
        name: name,
        parentId: browseFolderId,
      );
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _status = context.strings.createFolderFailed(error),
      );
    }
  }

  Future<void> renameFolder(ProjectFolder folder) async {
    final name = await _promptFolderName(
      title: context.strings.renameFolder,
      initial: folder.name,
    );
    if (name == null || !mounted) return;
    try {
      await AppScope.foldersOf(context).renameFolder(
        folderId: folder.id,
        name: name,
      );
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = context.strings.renameFolderFailed(error));
    }
  }

  Future<bool> _confirmDanger({
    required String title,
    required String detail,
    required String confirmLabel,
    bool danger = true,
  }) async {
    final strings = context.strings;
    final confirmed = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          AppTheme.spaceSm,
          AppTheme.pagePadding,
          AppTheme.pagePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(title, role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            AppText(detail, role: AppTextRole.caption),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: strings.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: danger
                        ? AppButtonVariant.danger
                        : AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> deleteFolder(ProjectFolder folder) async {
    final confirmed = await _confirmDanger(
      title: context.strings.deleteFolderTitle(folder.name),
      detail: context.strings.deleteFolderDetail,
      confirmLabel: context.strings.delete,
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.foldersOf(context).deleteFolder(folder.id);
      if (_browsePath.contains(folder.id)) {
        final cut = _browsePath.indexOf(folder.id);
        await _navigateBrowse(
          _browsePath.take(cut).toList(growable: false),
          forward: false,
        );
      } else {
        await reload();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = context.strings.deleteFolderFailed(error));
    }
  }

  Future<void> dissolveFolder(ProjectFolder folder) async {
    final confirmed = await _confirmDanger(
      title: context.strings.dissolveFolderTitle(folder.name),
      detail: context.strings.dissolveFolderDetail,
      confirmLabel: context.strings.dissolve,
      danger: false,
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.foldersOf(context).dissolveFolder(folder.id);
      if (_browsePath.contains(folder.id)) {
        final cut = _browsePath.indexOf(folder.id);
        await _navigateBrowse(
          _browsePath.take(cut).toList(growable: false),
          forward: false,
        );
      } else {
        await reload();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = context.strings.dissolveFolderFailed(error));
    }
  }

  Future<void> deleteSelected() async {
    final ids = widget.selection.selectedIds.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await _confirmDanger(
      title: context.strings.deleteItemsTitle(ids.length),
      detail: context.strings.deleteItemsDetail,
      confirmLabel: context.strings.delete,
    );
    if (!confirmed || !mounted) return;
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    final saves = AppScope.savesOf(context);
    final folderIds = _folders.map((f) => f.id).toSet();
    for (final id in ids) {
      if (folderIds.contains(id)) {
        await folders.deleteFolder(id);
      } else {
        await saves.clearForProject(id);
        await folders.removeProjectMembership(id);
        await projects.delete(id);
        await _dropAssistantConversation(id);
      }
    }
    widget.selection.exit();
    if (!mounted) return;
    if (ids.contains(_selectedProjectId)) {
      setState(() => _selectedProjectId = null);
    }
    await reload();
  }

  Future<void> moveSelected() async {
    final ids = widget.selection.selectedIds.toList(growable: false);
    if (ids.isEmpty) return;
    final strings = context.strings;
    final folders = AppScope.foldersOf(context);
    final allFolders = <ProjectFolder>[];
    Future<void> collect(String? parentId) async {
      final children = await folders.listFolders(parentId: parentId);
      for (final child in children) {
        if (ids.contains(child.id)) continue;
        allFolders.add(child);
        await collect(child.id);
      }
    }

    await collect(null);
    if (!mounted) return;
    final target = await showAppSheet<String?>(
      context: context,
      size: AppSheetSize.half,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.only(
          top: AppTheme.spaceSm,
          bottom: AppTheme.pagePadding,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePadding,
            ),
            child: AppText(strings.moveToTitle, role: AppTextRole.subtitle),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppListTile(
            title: strings.allStories,
            icon: Icons.home_outlined,
            onTap: () => Navigator.of(ctx).pop('__root__'),
          ),
          for (final folder in allFolders)
            AppListTile(
              title: folder.name,
              icon: Icons.folder_outlined,
              onTap: () => Navigator.of(ctx).pop(folder.id),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final folderTarget = target == '__root__' ? null : target;
    final projectIds = <String>[];
    final folderIds = <String>[];
    final knownFolders = {for (final f in _folders) f.id};
    // Also treat selected ids that aren't visible projects as folders when
    // nested; resolve via getFolder.
    for (final id in ids) {
      if (knownFolders.contains(id) ||
          await folders.getFolder(id) != null) {
        folderIds.add(id);
      } else {
        projectIds.add(id);
      }
    }
    try {
      if (projectIds.isNotEmpty) {
        await folders.moveProjects(
          projectIds: projectIds,
          folderId: folderTarget,
        );
      }
      for (final id in folderIds) {
        await folders.moveFolder(folderId: id, parentId: folderTarget);
      }
      widget.selection.exit();
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = context.strings.moveFailed(error));
    }
  }

  void toggleSelectAllVisible() {
    final ids = <String>[
      ..._visibleFolders.map((f) => f.id),
      ..._visibleProjects.map((p) => p.id),
    ];
    widget.selection.toggleSelectAll(ids);
  }

  Future<void> _deleteOneProject(String projectId) async {
    final confirmed = await _confirmDanger(
      title: context.strings.deleteStoryTitle,
      detail: context.strings.deleteStoryDetail,
      confirmLabel: context.strings.delete,
    );
    if (!confirmed || !mounted) return;
    AppLog.instance.info('删除故事：$projectId', tag: 'works.story');
    final saves = AppScope.savesOf(context);
    final folders = AppScope.foldersOf(context);
    final projects = AppScope.projectsOf(context);
    await saves.clearForProject(projectId);
    await folders.removeProjectMembership(projectId);
    await projects.delete(projectId);
    await _dropAssistantConversation(projectId);
    if (!mounted) return;
    if (_selectedProjectId == projectId) {
      setState(() => _selectedProjectId = null);
    }
    await reload();
  }

  /// The assistant's conversation belongs to the story card, so it goes away
  /// with it.
  Future<void> _dropAssistantConversation(String projectId) async {
    AppScope.createAssistantOf(context).forgetStory(projectId);
    await CreateAssistantDraftStore().removeStory(projectId);
  }

  String _formatUpdated(BuildContext context, DateTime updatedAt) {
    final local = updatedAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return context.strings.updatedOn('$y-$m-$d');
  }

  Future<void> _folderMenu(ProjectFolder folder) async {
    final strings = context.strings;
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: strings.openAction,
            icon: Icons.folder_open_outlined,
            onTap: () => Navigator.of(ctx).pop('open'),
          ),
          AppListTile(
            title: strings.renameAction,
            icon: Icons.drive_file_rename_outline,
            onTap: () => Navigator.of(ctx).pop('rename'),
          ),
          AppListTile(
            title: strings.dissolveFolderAction,
            icon: Icons.folder_off_outlined,
            onTap: () => Navigator.of(ctx).pop('dissolve'),
          ),
          AppListTile(
            title: strings.deleteFolderAction,
            icon: Icons.delete_outline,
            danger: true,
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop('delete'),
          ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        openFolder(folder.id);
      case 'rename':
        await renameFolder(folder);
      case 'dissolve':
        await dissolveFolder(folder);
      case 'delete':
        await deleteFolder(folder);
    }
  }

  Future<void> _projectMenu(ProjectSummary project) async {
    final strings = context.strings;
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: strings.playStory,
            icon: Icons.play_arrow_rounded,
            onTap: () => Navigator.of(ctx).pop('play'),
          ),
          AppListTile(
            title: strings.viewStory,
            icon: Icons.visibility_outlined,
            onTap: () => Navigator.of(ctx).pop('view'),
          ),
          AppListTile(
            title: strings.editStory,
            icon: Icons.edit_note_outlined,
            onTap: () => Navigator.of(ctx).pop('edit'),
          ),
          AppListTile(
            title: strings.exportStoryPack,
            icon: Icons.ios_share_outlined,
            onTap: () => Navigator.of(ctx).pop('export'),
          ),
          AppListTile(
            title: strings.deleteStory,
            icon: Icons.delete_outline,
            danger: true,
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop('delete'),
          ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'play':
        await _startPlay(project);
      case 'view':
        widget.selection.exit();
        AppLog.instance.info('查看故事：${project.title}', tag: 'works.story');
        await _openRoute(ProjectHubPage(projectId: project.id));
      case 'edit':
        widget.selection.exit();
        AppLog.instance.info('编辑故事：${project.title}', tag: 'works.story');
        await _openRoute(CreateHubPage(projectId: project.id));
      case 'export':
        await exportPack(project);
      case 'delete':
        await _deleteOneProject(project.id);
    }
  }

  Future<void> _startPlay(ProjectSummary summary) async {
    widget.selection.exit();
    try {
      final project = await AppScope.projectsOf(context).open(summary.id);
      if (!mounted) return;
      AppLog.instance.info('开始故事：${summary.title}', tag: 'works.story');
      await startNewPlay(context, project);
      if (mounted) await reload();
    } catch (error, stack) {
      AppLog.instance.error(
        '开始故事失败',
        tag: 'works.story',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      showAppToast(context, context.strings.cannotStart(error));
    }
  }

  Future<void> showViewModePicker() async {
    final display = AppScope.libraryDisplayOf(context);
    final strings = context.strings;
    final current = display.prefs.viewMode;
    final scheme = Theme.of(context).colorScheme;
    final selected = await showAppSheet<LibraryViewMode>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceMd,
            ),
            child: AppText(strings.displayMode, role: AppTextRole.subtitle),
          ),
          for (final mode in LibraryViewMode.values)
            AppListTile(
              title: libraryViewModeLabel(strings, mode),
              icon: mode.icon,
              selected: mode == current,
              trailing: mode == current
                  ? Icon(Icons.check, color: scheme.primary)
                  : null,
              onTap: () => Navigator.of(ctx).pop(mode),
            ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await display.setViewMode(selected);
  }

  Future<void> showAvatarShapePicker() async {
    final display = AppScope.libraryDisplayOf(context);
    final strings = context.strings;
    final current = display.prefs.avatarShape;
    final scheme = Theme.of(context).colorScheme;
    final selected = await showAppSheet<LibraryAvatarShape>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceMd,
            ),
            child: AppText(strings.avatarShape, role: AppTextRole.subtitle),
          ),
          for (final shape in LibraryAvatarShape.values)
            AppListTile(
              title: libraryAvatarShapeLabel(strings, shape),
              icon: shape.icon,
              selected: shape == current,
              trailing: shape == current
                  ? Icon(Icons.check, color: scheme.primary)
                  : null,
              onTap: () => Navigator.of(ctx).pop(shape),
            ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await display.setAvatarShape(selected);
  }

  Widget _browseList({
    required List<ProjectFolder> folders,
    required List<ProjectSummary> projects,
    required bool split,
  }) {
    final searching = _query.trim().isNotEmpty;
    if (folders.isEmpty && projects.isEmpty && searching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: AppEmptyState(
            message: context.strings.noMatchingStories,
            detail: context.strings.noMatchDetail,
          ),
        ),
      );
    }

    final selectionMode = widget.selection.selectionMode;
    final display = AppScope.libraryDisplayOf(context).prefs;
    return RefreshIndicator(
      onRefresh: reload,
      child: LibraryBrowseViews(
        viewMode: display.viewMode,
        avatarShape: display.avatarShape,
        folders: folders,
        projects: projects,
        covers: _covers,
        selection: widget.selection,
        activeId: split ? _selectedProjectId : null,
        onOpenFolder: (folder) => openFolder(folder.id),
        onOpenProject: (project) => _openProject(project, split: split),
        onFolderMenu: _folderMenu,
        onProjectMenu: _projectMenu,
        formatUpdated: (updatedAt) => _formatUpdated(context, updatedAt),
        onCreate: selectionMode || searching ? null : showCreateSheet,
      ),
    );
  }

  Future<void> showCreateSheet() async {
    final strings = context.strings;
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: strings.newBlankStory,
            icon: Icons.note_add_outlined,
            onTap: () => Navigator.of(ctx).pop('blank'),
          ),
          AppListTile(
            title: strings.pasteStory,
            icon: Icons.content_paste_outlined,
            onTap: () => Navigator.of(ctx).pop('novel'),
          ),
          AppListTile(
            title: strings.stagedPrompts,
            icon: Icons.timeline_outlined,
            onTap: () => Navigator.of(ctx).pop('staged'),
          ),
          AppListTile(
            title: strings.importCard,
            icon: Icons.badge_outlined,
            onTap: () => Navigator.of(ctx).pop('card'),
          ),
          AppListTile(
            title: strings.importStoryPack,
            icon: Icons.folder_zip_outlined,
            onTap: () => Navigator.of(ctx).pop('import'),
          ),
          AppListTile(
            title: strings.newFolder,
            icon: Icons.create_new_folder_outlined,
            onTap: () => Navigator.of(ctx).pop('folder'),
          ),
          AppListTile(
            title: strings.trySampleStory,
            icon: Icons.auto_stories_outlined,
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop('sample'),
          ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'blank':
        await createBlank();
      case 'card':
        await openCreateEntry(CreateEntryKind.characterCard);
      case 'novel':
        await openCreateEntry(CreateEntryKind.novel);
      case 'staged':
        await openCreateEntry(CreateEntryKind.stagedPrompts);
      case 'import':
        await importPack();
      case 'folder':
        await createFolder();
      case 'sample':
        await addSample();
    }
  }

  Future<void> showMoreMenu() async {
    final strings = context.strings;
    final display = AppScope.libraryDisplayOf(context).prefs;
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: strings.displayMode,
            subtitle: libraryViewModeLabel(strings, display.viewMode),
            icon: display.viewMode.icon,
            onTap: () => Navigator.of(ctx).pop('view_mode'),
          ),
          if (display.viewMode == LibraryViewMode.list)
            AppListTile(
              title: strings.avatarShape,
              subtitle: libraryAvatarShapeLabel(strings, display.avatarShape),
              icon: display.avatarShape.icon,
              onTap: () => Navigator.of(ctx).pop('avatar_shape'),
            ),
          AppListTile(
            title: strings.multiSelect,
            icon: Icons.checklist,
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop('select'),
          ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'view_mode':
        await showViewModePicker();
      case 'avatar_shape':
        await showAvatarShapePicker();
      case 'select':
        widget.selection.enter(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paneWidth = AppScope.paneWidthOf(context);
    final selectedId = _selectedProjectId;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same constraints AppMasterDetail measures, so tap behaviour and the
        // rendered column count can never disagree.
        final split = AppLayout.useMasterDetail(constraints.maxWidth);
        _rendersSplit = split;
        return AppMasterDetail(
          primary: _masterPane(context, split),
          // Same page a narrow window pushes: the third column *is* the story
          // page, and its editors / play session open on top of it in place.
          detail: selectedId == null
              ? null
              : ProjectHubPage(
                  key: ValueKey<String>('story-pane-$selectedId'),
                  projectId: selectedId,
                ),
          emptyLabel: context.strings.selectStoryHint,
          paneWidth: paneWidth,
          detailController: _detailPane,
        );
      },
    );
  }

  Widget _masterPane(BuildContext context, bool split) {
    final strings = context.strings;
    final selectionMode = widget.selection.selectionMode;
    final folders = _visibleFolders;
    final projects = _visibleProjects;
    final pathKey = _browsePath.join('/');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          hint: strings.searchStoriesHint,
          controller: _searchController,
          onChanged: (value) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 200), () {
              if (mounted) setState(() => _query = value);
            });
          },
          onClear: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            AppTheme.spaceXs,
          ),
          child: SizedBox(
            height: _WorksBreadcrumb.rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (selectionMode) ...[
                  AppIconButton(
                    icon: Icons.close,
                    tooltip: strings.exitSelection,
                    onPressed: () => widget.selection.exit(),
                  ),
                  const Spacer(),
                  ...AppPage.spacedActions([
                    AppIconButton(
                      icon: widget.selection.hasSelection
                          ? Icons.deselect
                          : Icons.select_all,
                      tooltip: strings.selectAll(
                        widget.selection.hasSelection,
                      ),
                      onPressed: toggleSelectAllVisible,
                    ),
                    if (widget.selection.hasSelection)
                      AppIconButton(
                        icon: Icons.drive_file_move_outline,
                        tooltip: strings.moveToFolder,
                        onPressed: moveSelected,
                      ),
                    if (widget.selection.hasSelection)
                      AppIconButton(
                        icon: Icons.delete_outline,
                        tooltip: strings.delete,
                        danger: true,
                        onPressed: deleteSelected,
                      ),
                  ]),
                ] else ...[
                  Expanded(
                    child: _WorksBreadcrumb(
                      crumbs: _breadcrumbs,
                      onRoot: () => jumpBreadcrumb(-1),
                      onCrumb: jumpBreadcrumb,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.more_vert,
                    tooltip: strings.storyOptions,
                    onPressed: showMoreMenu,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
            child: AppText(_status!, role: AppTextRole.caption),
          ),
        Expanded(
          child: _loading
              ? Center(
                  child: AppText(strings.loading, role: AppTextRole.caption),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    // Flutter AnimatedSwitcher reverses the *controller* for
                    // outgoing children (no ReverseAnimation wrapper). Detect
                    // incoming vs outgoing by matching the current path key.
                    final currentKey = ValueKey<String>('browse-$pathKey');
                    final incoming = child.key == currentKey;
                    final Offset begin;
                    if (_folderEnterForward) {
                      // Enter folder: old ← left, new from right.
                      begin = incoming
                          ? const Offset(1, 0)
                          : const Offset(-1, 0);
                    } else {
                      // Leave folder: old → right, new from left.
                      begin = incoming
                          ? const Offset(-1, 0)
                          : const Offset(1, 0);
                    }
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: begin,
                        end: Offset.zero,
                      ).animate(animation),
                      child: ColoredBox(
                        // Match the master pane background so the wide-window
                        // surface step is not painted over mid-slide.
                        color: split
                            ? Theme.of(context).colorScheme.surfaceContainerLow
                            : Theme.of(context).colorScheme.surface,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>('browse-$pathKey'),
                    child: _browseList(
                      folders: folders,
                      projects: projects,
                      split: split,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _WorksBreadcrumb extends StatelessWidget {
  const _WorksBreadcrumb({
    required this.crumbs,
    required this.onRoot,
    required this.onCrumb,
  });

  static const double rowHeight = 36;
  static const double _chipHeight = 28;

  final List<ProjectFolder> crumbs;
  final VoidCallback onRoot;
  final ValueChanged<int> onCrumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.0,
        );
    final active = muted?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
    );
    final atRoot = crumbs.isEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BreadcrumbChip(
            label: context.strings.browseRoot,
            style: atRoot ? active : muted,
            filled: true,
            height: _chipHeight,
            onTap: atRoot ? null : onRoot,
          ),
          for (var i = 0; i < crumbs.length; i++) ...[
            Icon(
              Icons.chevron_right,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            _BreadcrumbChip(
              label: crumbs[i].name,
              style: i == crumbs.length - 1 ? active : muted,
              filled: false,
              height: _chipHeight,
              onTap: i == crumbs.length - 1 ? null : () => onCrumb(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.label,
    required this.style,
    required this.filled,
    required this.height,
    this.onTap,
  });

  final String label;
  final TextStyle? style;
  final bool filled;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTheme.radiusMd - 4);
    final labelText = Text(
      label,
      style: style,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );

    return Material(
      color: filled ? scheme.surfaceContainerHighest : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: filled ? AppTheme.spaceSm : AppTheme.spaceXs,
            ),
            child: Center(child: labelText),
          ),
        ),
      ),
    );
  }
}
