import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_search_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:flutter/material.dart';

class SavesTab extends StatefulWidget {
  const SavesTab({
    super.key,
    required this.selection,
    required this.onBrowseWorks,
    this.onSelectionChromeChanged,
  });

  final LibrarySelectionController selection;
  final VoidCallback onBrowseWorks;
  final VoidCallback? onSelectionChromeChanged;

  @override
  State<SavesTab> createState() => SavesTabState();
}

class SavesTabState extends State<SavesTab> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  List<_SaveRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_onSelectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    widget.onSelectionChromeChanged?.call();
    setState(() {});
  }

  Future<void> reload() async {
    final saves = AppScope.savesOf(context);
    final projects = AppScope.projectsOf(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await saves.listAll();
      final summaries = await projects.listProjects();
      final byId = {for (final s in summaries) s.id: s};
      final rows = <_SaveRow>[];
      for (final slot in slots) {
        final summary = byId[slot.projectId];
        if (summary == null) continue;
        rows.add(_SaveRow(slot: slot, project: summary));
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  List<_SaveRow> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows
        .where((row) => row.project.title.toLowerCase().contains(q))
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

  Future<void> _resumePlay(_SaveRow row) async {
    widget.selection.exit();
    try {
      final project =
          await AppScope.projectsOf(context).open(row.project.id);
      if (!mounted) return;
      await _openRoute(
        PlaySessionPage(
          project: project,
          mode: row.slot.mode,
          slotId: row.slot.id,
          resumeSave: true,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法继续：$error')),
      );
    }
  }

  Future<void> _openStory(_SaveRow row) {
    widget.selection.exit();
    return _openRoute(ProjectHubPage(projectId: row.project.id));
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
            const AppText('删除这些存档？', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '只清掉进度，故事本身还在',
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
    for (final id in ids) {
      await saves.clear(id);
    }
    widget.selection.exit();
    await reload();
  }

  Future<void> _deleteOne(String slotId) async {
    widget.selection.exit();
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
            const AppText('删除这个存档？', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '只清掉进度，故事本身还在',
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
    await AppScope.savesOf(context).clear(slotId);
    await reload();
  }

  String _formatRelative(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _subtitle(_SaveRow row) {
    final kind =
        row.slot.mode == PlayViewMode.chat ? '聊天' : '视觉小说';
    return '$kind · 上次游玩 ${_formatRelative(row.slot.savedAt)}';
  }

  Widget _leading({required bool selected, required bool selectionMode}) {
    final scheme = Theme.of(context).colorScheme;
    if (selectionMode) {
      return Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? scheme.primary : scheme.outline,
      );
    }
    return CircleAvatar(
      backgroundColor: scheme.primary.withValues(alpha: 0.18),
      child: Icon(Icons.menu_book_outlined, color: scheme.primary, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectionMode = widget.selection.selectionMode;
    final visible = _visible;
    final mediaBottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          hint: '搜索会话',
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          onClear: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
        Expanded(
          child: _loading
              ? const Center(child: AppText('加载中…', role: AppTextRole.caption))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.pagePadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText('加载失败：$_error', role: AppTextRole.caption),
                            const SizedBox(height: AppTheme.spaceMd),
                            AppButton(label: '重试', onPressed: reload),
                          ],
                        ),
                      ),
                    )
                  : visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.pagePadding),
                            child: AppEmptyState(
                              message: _query.trim().isEmpty
                                  ? '还没有进行中的会话'
                                  : '没有匹配的会话',
                              detail: _query.trim().isEmpty
                                  ? '开玩视觉小说或聊天后会出现在这里'
                                  : '换个关键词试试',
                              action: _query.trim().isEmpty
                                  ? AppButton(
                                      label: '去故事',
                                      onPressed: widget.onBrowseWorks,
                                      variant: AppButtonVariant.secondary,
                                    )
                                  : null,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: reload,
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              0,
                              AppTheme.spaceXs,
                              0,
                              AppTheme.pagePadding + mediaBottom + 72,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox.shrink(),
                            itemBuilder: (context, index) {
                              final row = visible[index];
                              final selected =
                                  widget.selection.isSelected(row.slot.id);
                              return AppListTile(
                                title: row.project.title,
                                subtitle: _subtitle(row),
                                selected: selectionMode && selected,
                                leading: _leading(
                                  selected: selected,
                                  selectionMode: selectionMode,
                                ),
                                trailing: selectionMode
                                    ? null
                                    : AppIconButton(
                                        icon: Icons.more_vert,
                                        tooltip: '更多',
                                        onPressed: () async {
                                          final action =
                                              await showAppSheet<String>(
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  AppButton(
                                                    label: '继续游玩',
                                                    expanded: true,
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop('resume'),
                                                  ),
                                                  const SizedBox(
                                                    height: AppTheme.spaceSm,
                                                  ),
                                                  AppButton(
                                                    label: '打开故事',
                                                    variant: AppButtonVariant
                                                        .secondary,
                                                    expanded: true,
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop('story'),
                                                  ),
                                                  const SizedBox(
                                                    height: AppTheme.spaceSm,
                                                  ),
                                                  AppButton(
                                                    label: '删除存档',
                                                    variant: AppButtonVariant
                                                        .ghost,
                                                    expanded: true,
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop('delete'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                          if (!mounted) return;
                                          if (action == 'resume') {
                                            await _resumePlay(row);
                                          } else if (action == 'story') {
                                            await _openStory(row);
                                          } else if (action == 'delete') {
                                            await _deleteOne(row.slot.id);
                                          }
                                        },
                                      ),
                                onTap: () {
                                  if (selectionMode) {
                                    widget.selection.toggle(row.slot.id);
                                  } else {
                                    _resumePlay(row);
                                  }
                                },
                                onLongPress: () =>
                                    widget.selection.toggle(row.slot.id),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _SaveRow {
  const _SaveRow({required this.slot, required this.project});

  final SaveSlot slot;
  final ProjectSummary project;
}
