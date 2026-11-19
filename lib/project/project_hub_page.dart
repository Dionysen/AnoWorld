import 'dart:io';

import 'package:anoworld/app/app_scope.dart';
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
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_detail_entry.dart';
import 'package:anoworld/foundation/widgets/app_detail_section.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/play/play_mode_sheet.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Story overview: cover, structured sections, play actions, per-section edit.
class ProjectHubPage extends StatefulWidget {
  const ProjectHubPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectHubPage> createState() => _ProjectHubPageState();
}

class _ProjectHubPageState extends State<ProjectHubPage> {
  Project? _project;
  Object? _error;
  bool _loading = true;
  bool _loadScheduled = false;
  String? _projectDir;
  String? _coverAbsolutePath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadScheduled) return;
    _loadScheduled = true;
    _load();
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
    if (projectDir == null || relative == null || relative.trim().isEmpty) {
      return null;
    }
    final absolute = ProjectCoverFiles.absolutePath(projectDir, relative);
    if (await File(absolute).exists()) return absolute;
    return null;
  }

  Future<void> _persist(Project project) async {
    final stamped = project.copyWith(
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    await AppScope.projectsOf(context).save(stamped);
    if (!mounted) return;
    final coverPath =
        await _resolveCoverPath(_projectDir, stamped.meta.coverPath);
    if (!mounted) return;
    setState(() {
      _project = stamped;
      _coverAbsolutePath = coverPath;
    });
  }

  Future<void> _changeCover() async {
    final project = _project;
    final dir = _projectDir;
    if (project == null) return;
    if (dir == null) {
      showAppToast(context, '当前故事还不能换封面');
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
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                AppTheme.spaceSm,
              ),
              child: AppSectionHeader('封面'),
            ),
            AppListTile(
              title: '选择图片',
              icon: Icons.image_outlined,
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (project.meta.coverPath != null)
              AppListTile(
                title: '恢复默认',
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
      showAppToast(context, '无法更换封面：$error');
    }
  }

  Future<void> _play() async {
    final project = _project;
    if (project == null) return;
    final mode = await showPlayModeSheet(context);
    if (!mounted || mode == null) return;
    await pushAppSlide(
      context,
      PlaySessionPage(
        project: project,
        mode: mode,
        resumeSave: false,
      ),
    );
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
    return [...always, ...keyed].map(_worldBookEntry).toList(growable: false);
  }

  static AppDetailEntry _worldBookEntry(WorldBookEntry entry) {
    final title = entry.title.trim();
    return AppDetailEntry(
      title: title.isEmpty ? '未命名条目' : title,
      tags: _worldBookTags(entry),
      body: entry.body.trim(),
    );
  }

  static List<String> _worldBookTags(WorldBookEntry entry) {
    if (entry.alwaysOn) return const <String>['常驻'];
    if (entry.keys.isEmpty) return const <String>['按需'];
    return entry.keys;
  }

  List<AppDetailEntry> _castEntries(Project project) {
    return project.cast.map(_castEntry).toList(growable: false);
  }

  static AppDetailEntry _castEntry(CastMember member) {
    final tags = <String>[
      if (member.isProtagonist) '主角',
      if (member.exampleLines.isNotEmpty) '示例对白',
    ];
    return AppDetailEntry(
      title: member.name.trim().isEmpty ? '未命名角色' : member.name.trim(),
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
          title: '脉络摘要',
          tags: const <String>['概要'],
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

  String _mainSubtitle(Project project) {
    final nodes = project.main.nodes.length;
    final edges = project.main.edges.length;
    if (nodes == 0) return '还没有大情节站';
    return '$nodes 站 · $edges 条连线';
  }

  List<AppDetailEntry> _plotElementEntries(Project project) {
    final catalog = AppScope.settingsOf(context).plotElements;
    final rows = catalog.resolveSelected(project.plotElements.selectedIds);
    return rows
        .map(
          (e) => AppDetailEntry(
            title: e.keyword.trim().isEmpty ? '未命名' : e.keyword.trim(),
            tags: catalog.isBuiltInId(e.id)
                ? const <String>['默认']
                : const <String>[],
            body: e.clippedDescription,
          ),
        )
        .toList(growable: false);
  }

  Widget _storyCover(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = _coverAbsolutePath;
    final letter = title.isEmpty ? '?' : title.characters.first;
    final placeholder = ColoredBox(
      color: scheme.primary.withValues(alpha: 0.16),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 56,
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round()
            : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (coverPath != null)
              Image.file(
                File(coverPath),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => placeholder,
              )
            else
              placeholder,
            Positioned(
              top: AppTheme.spaceSm,
              right: AppTheme.spaceSm,
              child: AppCircleButton(
                icon: Icons.photo_outlined,
                tooltip: '更换封面',
                onPressed: _changeCover,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final title =
        project?.meta.title.trim().isEmpty == true ||
                project == null
            ? '未命名故事'
            : project.meta.title;

    final ready = project != null && !_loading && _error == null;

    return AppPage(
      title: title,
      onBack: () => Navigator.of(context).maybePop(),
      actions: ready
          ? [
              AppCircleButton(
                icon: Icons.edit_note_outlined,
                tooltip: '继续创作',
                onPressed: _openCreateHub,
              ),
            ]
          : const [],
      floatingActionButton: ready
          ? SizedBox.square(
              dimension: AppCircleButton.fabDiameter,
              child: AppCircleButton.fab(
                icon: Icons.play_arrow_rounded,
                tooltip: '开始游玩',
                onPressed: _play,
              ),
            )
          : null,
      body: AppPageBody.list(
        children: [
          if (_loading)
            const AppPageGutter(
              child: AppText('加载中…', role: AppTextRole.caption),
            )
          else if (_error != null)
            AppPageGutter(
              child: AppEmptyState(
                message: '无法打开故事',
                detail: _error.toString(),
                action: AppButton(
                  label: '重试',
                  onPressed: _load,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            )
          else if (project != null) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _storyCover(context, project.meta.title),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppDetailSection(
              title: '世界书',
              icon: Icons.public_outlined,
              entries: _worldBookEntries(project),
              emptyHint: '还没有世界观与设定',
              onEdit: () => _openEditor(
                WorldBookEditorPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppDetailSection(
              title: '角色',
              icon: Icons.groups_outlined,
              entries: _castEntries(project),
              emptyHint: '还没有角色',
              onEdit: () => _openEditor(
                CastEditorPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppDetailSection(
              title: '情节走向',
              icon: Icons.account_tree_outlined,
              entries: _mainEntries(project),
              emptyHint: _mainSubtitle(project),
              onEdit: () => _openEditor(
                MainGraphPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppDetailSection(
              title: '剧情元素',
              icon: Icons.theater_comedy_outlined,
              entries: _plotElementEntries(project),
              emptyHint: '还没选剧情元素',
              onEdit: () => _openEditor(
                PlotElementsPickPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(
              height: AppCircleButton.fabDiameter + AppTheme.spaceLg,
            ),
          ],
        ],
      ),
    );
  }
}