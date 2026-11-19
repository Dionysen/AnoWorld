import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_search_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
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

  Future<void> _openRoute(Widget page, {bool storyChrome = false}) async {
    if (storyChrome) {
      await pushStoryRoute<void>(context, page);
    } else {
      await pushAppSlide(context, page);
    }
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
      showAppToast(context, context.strings.cannotResume(error));
    }
  }

  Future<void> _openStory(_SaveRow row) {
    widget.selection.exit();
    return _openRoute(
      ProjectHubPage(projectId: row.project.id),
      storyChrome: true,
    );
  }

  void _toggleSelectAllVisible() {
    final ids = _visible.map((row) => row.slot.id).toList(growable: false);
    widget.selection.toggleSelectAll(ids);
  }

  Future<void> deleteSelected() async {
    final ids = widget.selection.selectedIds.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await _confirmDelete(context.strings.deleteSavesTitle);
    if (!confirmed || !mounted) return;
    final saves = AppScope.savesOf(context);
    for (final id in ids) {
      await saves.clear(id);
    }
    widget.selection.exit();
    await reload();
  }

  Future<bool> _confirmDelete(String title) async {
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
            AppText(strings.deleteSaveDetail, role: AppTextRole.caption),
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
                    label: strings.delete,
                    variant: AppButtonVariant.danger,
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

  Future<void> _deleteOne(String slotId) async {
    widget.selection.exit();
    final confirmed = await _confirmDelete(context.strings.deleteSaveTitle);
    if (!confirmed || !mounted) return;
    await AppScope.savesOf(context).clear(slotId);
    await reload();
  }

  String _formatRelative(BuildContext context, DateTime at) {
    final strings = context.strings;
    final local = at.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return strings.justNow;
    if (diff.inHours < 1) return strings.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return strings.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return strings.daysAgo(diff.inDays);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _subtitle(BuildContext context, _SaveRow row) {
    final strings = context.strings;
    final kind = row.slot.mode == PlayViewMode.chat
        ? strings.kindChat
        : strings.kindVisualNovel;
    return strings.lastPlayed(kind, _formatRelative(context, row.slot.savedAt));
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
    final strings = context.strings;
    final selectionMode = widget.selection.selectionMode;
    final visible = _visible;
    final mediaBottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          hint: strings.searchSavesHint,
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
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
            height: 36,
            child: Row(
              children: [
                const Spacer(),
                if (selectionMode) ...[
                  AppIconButton(
                    icon: Icons.close,
                    tooltip: strings.exitSelection,
                    onPressed: () => widget.selection.exit(),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  AppIconButton(
                    icon: widget.selection.hasSelection
                        ? Icons.deselect
                        : Icons.select_all,
                    tooltip: strings.selectAll(widget.selection.hasSelection),
                    onPressed: _toggleSelectAllVisible,
                  ),
                  if (widget.selection.hasSelection) ...[
                    const SizedBox(width: AppTheme.spaceSm),
                      AppIconButton(
                        icon: Icons.delete_outline,
                        tooltip: strings.delete,
                        danger: true,
                        onPressed: deleteSelected,
                    ),
                  ],
                ] else
                  AppIconButton(
                    icon: Icons.checklist,
                    tooltip: strings.multiSelect,
                    onPressed: () => widget.selection.enter(null),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? Center(
                  child: AppText(strings.loading, role: AppTextRole.caption),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.pagePadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              strings.loadFailed(_error!),
                              role: AppTextRole.caption,
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                            AppButton(label: strings.retry, onPressed: reload),
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
                                  ? strings.noSavesMessage
                                  : strings.noMatchMessage,
                              detail: _query.trim().isEmpty
                                  ? strings.noSavesDetail
                                  : strings.noMatchDetail,
                              action: _query.trim().isEmpty
                                  ? AppButton(
                                      label: strings.goStories,
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
                                subtitle: _subtitle(context, row),
                                selected: selectionMode && selected,
                                leading: _leading(
                                  selected: selected,
                                  selectionMode: selectionMode,
                                ),
                                trailing: selectionMode
                                    ? null
                                    : AppIconButton(
                                        icon: Icons.more_vert,
                                        tooltip: strings.more,
                                        onPressed: () async {
                                          final action =
                                              await showAppSheet<String>(
                                            context: context,
                                            builder: (ctx) => Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const SizedBox(
                                                  height: AppTheme.spaceSm,
                                                ),
                                                AppListTile(
                                                  title: strings.resumePlay,
                                                  icon: Icons
                                                      .play_arrow_rounded,
                                                  onTap: () =>
                                                      Navigator.of(ctx)
                                                          .pop('resume'),
                                                ),
                                                AppListTile(
                                                  title: strings.openStory,
                                                  icon: Icons
                                                      .menu_book_outlined,
                                                  onTap: () =>
                                                      Navigator.of(ctx)
                                                          .pop('story'),
                                                ),
                                                AppListTile(
                                                  title: strings.deleteSave,
                                                  icon:
                                                      Icons.delete_outline,
                                                  danger: true,
                                                  showDivider: false,
                                                  onTap: () =>
                                                      Navigator.of(ctx)
                                                          .pop('delete'),
                                                ),
                                                const SizedBox(
                                                  height: AppTheme.pagePadding,
                                                ),
                                              ],
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
