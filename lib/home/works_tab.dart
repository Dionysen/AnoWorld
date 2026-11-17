import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/create_entry_page.dart';
import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_folder.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_search_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/home/library_browse_views.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class WorksTab extends StatefulWidget {
  const WorksTab({
    super.key,
    required this.selection,
    this.pickImportDirectory,
    this.onSelectionChromeChanged,
    this.onBrowsePathChanged,
  });

  final LibrarySelectionController selection;
  final Future<String?> Function()? pickImportDirectory;
  final VoidCallback? onSelectionChromeChanged;
  final ValueChanged<List<String>>? onBrowsePathChanged;

  @override
  State<WorksTab> createState() => WorksTabState();
}

class WorksTabState extends State<WorksTab> {
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

  List<String> get browsePath => List<String>.unmodifiable(_browsePath);

  String? get browseFolderId =>
      _browsePath.isEmpty ? null : _browsePath.last;

  bool get folderEnterForward => _folderEnterForward;

  LibraryDisplayController? _display;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_onSelectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _display = AppScope.libraryDisplayOf(context);
      _display!.addListener(_onDisplayChanged);
      reload();
    });
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChanged);
    _display?.removeListener(_onDisplayChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    widget.onSelectionChromeChanged?.call();
    setState(() {});
  }

  void _onDisplayChanged() => setState(() {});

  void _setBrowsePath(List<String> next, {required bool forward}) {
    setState(() {
      _folderEnterForward = forward;
      _browsePath
        ..clear()
        ..addAll(next);
    });
    widget.onBrowsePathChanged?.call(browsePath);
  }

  void openFolder(String folderId) {
    widget.selection.exit();
    _setBrowsePath([..._browsePath, folderId], forward: true);
    reload();
  }

  void jumpBreadcrumb(int index) {
    widget.selection.exit();
    if (index < 0) {
      _setBrowsePath(const [], forward: false);
    } else {
      _setBrowsePath(_browsePath.take(index + 1).toList(), forward: false);
    }
    reload();
  }

  bool handleSystemBack() {
    if (widget.selection.selectionMode) {
      widget.selection.exit();
      return true;
    }
    if (_browsePath.isNotEmpty) {
      jumpBreadcrumb(_browsePath.length - 2);
      return true;
    }
    return false;
  }

  Future<void> reload() async {
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final all = await projects.listProjects();
      final folderId = browseFolderId;
      final listed = await folders.listFolders(parentId: folderId);
      final crumbs = folderId == null
          ? const <ProjectFolder>[]
          : await folders.breadcrumbs(folderId);
      final membership = <String, String?>{};
      for (final project in all) {
        membership[project.id] = await folders.folderIdForProject(project.id);
      }
      if (!mounted) return;
      setState(() {
        _allProjects = all;
        _folders = listed;
        _breadcrumbs = crumbs;
        _membership = membership;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '加载失败：$error';
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
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (mounted) await reload();
  }

  Future<void> createBlank() async {
    widget.selection.exit();
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    final folderId = browseFolderId;
    try {
      final project = await projects.create(title: '未命名故事');
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
      setState(() => _status = '新建失败：$error');
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
      setState(() => _status = '样例写入失败：$error');
    }
  }

  Future<void> importPack() async {
    widget.selection.exit();
    final projects = AppScope.projectsOf(context);
    final folders = AppScope.foldersOf(context);
    final folderId = browseFolderId;
    final picker = widget.pickImportDirectory ?? _defaultPickDirectory;
    final path = await picker();
    if (!mounted) return;
    if (path == null || path.isEmpty) return;
    try {
      final project = await projects.importFromDirectory(path);
      if (folderId != null) {
        await folders.moveProjects(
          projectIds: [project.meta.id],
          folderId: folderId,
        );
      }
      if (!mounted) return;
      setState(() => _status = '已导入「${project.meta.title}」');
      await _openRoute(ProjectHubPage(projectId: project.meta.id));
    } on ProjectIoException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '导入失败：$error');
    }
  }

  static Future<String?> _defaultPickDirectory() {
    return FilePicker.getDirectoryPath(dialogTitle: '选择 AnoWorld 故事包文件夹');
  }

  Future<void> openCreateEntry(CreateEntryKind kind) {
    widget.selection.exit();
    return _openRoute(CreateEntryPage(kind: kind));
  }

  Future<String?> _promptFolderName({
    required String title,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showAppSheet<String>(
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
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              label: '名称',
              controller: controller,
              hint: '文件夹名称',
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: '确定',
                    onPressed: () =>
                        Navigator.of(ctx).pop(controller.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> createFolder() async {
    widget.selection.exit();
    final name = await _promptFolderName(title: '新建文件夹');
    if (name == null || !mounted) return;
    try {
      await AppScope.foldersOf(context).createFolder(
        name: name,
        parentId: browseFolderId,
      );
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '新建文件夹失败：$error');
    }
  }

  Future<void> renameFolder(ProjectFolder folder) async {
    final name = await _promptFolderName(
      title: '重命名文件夹',
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
      setState(() => _status = '重命名失败：$error');
    }
  }

  Future<void> deleteFolder(ProjectFolder folder) async {
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
            AppText('删除「${folder.name}」？', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '里面的故事会回到上一层',
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: '删除',
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.foldersOf(context).deleteFolder(folder.id);
      if (_browsePath.contains(folder.id)) {
        final cut = _browsePath.indexOf(folder.id);
        _setBrowsePath(_browsePath.take(cut).toList(), forward: false);
      }
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '删除文件夹失败：$error');
    }
  }

  Future<void> dissolveFolder(ProjectFolder folder) async {
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
            AppText('解散「${folder.name}」？', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '文件夹会去掉，内容留在上一层',
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: '解散',
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.foldersOf(context).dissolveFolder(folder.id);
      if (_browsePath.contains(folder.id)) {
        final cut = _browsePath.indexOf(folder.id);
        _setBrowsePath(_browsePath.take(cut).toList(), forward: false);
      }
      await reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '解散失败：$error');
    }
  }

  Future<void> deleteSelected() async {
    final ids = widget.selection.selectedIds.toList(growable: false);
    if (ids.isEmpty) return;
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
            AppText('删除这 ${ids.length} 项？', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '故事会彻底删掉，文件夹里的故事会回到上一层',
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: '删除',
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
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
      }
    }
    widget.selection.exit();
    await reload();
  }

  Future<void> moveSelected() async {
    final ids = widget.selection.selectedIds.toList(growable: false);
    if (ids.isEmpty) return;
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
            child: AppText('移到…', role: AppTextRole.subtitle),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppListTile(
            title: '全部故事',
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
      setState(() => _status = '移动失败：$error');
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
            const AppText('删除这个故事？', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '故事和对应存档都会删掉',
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: '删除',
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final saves = AppScope.savesOf(context);
    final folders = AppScope.foldersOf(context);
    final projects = AppScope.projectsOf(context);
    await saves.clearForProject(projectId);
    await folders.removeProjectMembership(projectId);
    await projects.delete(projectId);
    await reload();
  }

  String _formatUpdated(DateTime updatedAt) {
    final local = updatedAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '更新 $y-$m-$d';
  }

  Future<void> _folderMenu(ProjectFolder folder) async {
    final action = await showAppSheet<String>(
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
            AppButton(
              label: '打开',
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('open'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '重命名',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('rename'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '解散文件夹',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('dissolve'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '删除文件夹',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
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
    final action = await showAppSheet<String>(
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
            AppButton(
              label: '打开',
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('open'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '删除故事',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'open') {
      widget.selection.exit();
      await _openRoute(ProjectHubPage(projectId: project.id));
    } else if (action == 'delete') {
      await _deleteOneProject(project.id);
    }
  }

  Future<void> showViewModePicker() async {
    final display = AppScope.libraryDisplayOf(context);
    final current = display.prefs.viewMode;
    final scheme = Theme.of(context).colorScheme;
    final selected = await showAppSheet<LibraryViewMode>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceMd,
            ),
            child: AppText('显示方式', role: AppTextRole.subtitle),
          ),
          for (final mode in LibraryViewMode.values)
            AppListTile(
              title: mode.label,
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
    final current = display.prefs.avatarShape;
    final scheme = Theme.of(context).colorScheme;
    final selected = await showAppSheet<LibraryAvatarShape>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceMd,
            ),
            child: AppText('头像形状', role: AppTextRole.subtitle),
          ),
          for (final shape in LibraryAvatarShape.values)
            AppListTile(
              title: shape.label,
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
  }) {
    final itemCount = folders.length + projects.length;
    if (itemCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: AppEmptyState(
            message: _query.trim().isEmpty ? '还没有故事' : '没有匹配的故事',
            detail: _query.trim().isEmpty
                ? '导入、粘贴故事，或试用内置样例'
                : '换个关键词试试',
            action: _query.trim().isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppButton(
                        label: '试用「雨夜投宿」',
                        onPressed: addSample,
                        variant: AppButtonVariant.secondary,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      AppButton(
                        label: '新建空白故事',
                        onPressed: createBlank,
                        variant: AppButtonVariant.ghost,
                      ),
                    ],
                  )
                : null,
          ),
        ),
      );
    }

    final display = AppScope.libraryDisplayOf(context).prefs;
    return RefreshIndicator(
      onRefresh: reload,
      child: LibraryBrowseViews(
        viewMode: display.viewMode,
        avatarShape: display.avatarShape,
        folders: folders,
        projects: projects,
        selection: widget.selection,
        onOpenFolder: (folder) => openFolder(folder.id),
        onOpenProject: (project) =>
            _openRoute(ProjectHubPage(projectId: project.id)),
        onFolderMenu: _folderMenu,
        onProjectMenu: _projectMenu,
        formatUpdated: _formatUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectionMode = widget.selection.selectionMode;
    final folders = _visibleFolders;
    final projects = _visibleProjects;
    final pathKey = _browsePath.join('/');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!selectionMode)
          _WorksBreadcrumb(
            crumbs: _breadcrumbs,
            onRoot: () => jumpBreadcrumb(-1),
            onCrumb: jumpBreadcrumb,
          ),
        AppSearchField(
          hint: '搜索故事',
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
        if (_status != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
            child: AppText(_status!, role: AppTextRole.caption),
          ),
        Expanded(
          child: _loading
              ? const Center(child: AppText('加载中…', role: AppTextRole.caption))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: Offset(_folderEnterForward ? 0.12 : -0.12, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(
                      'browse-$pathKey-${AppScope.libraryDisplayOf(context).prefs.viewMode.name}',
                    ),
                    child: _browseList(
                      folders: folders,
                      projects: projects,
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

  static const double _rowHeight = 36;
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

    return SizedBox(
      height: _rowHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _BreadcrumbChip(
              label: '故事',
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
