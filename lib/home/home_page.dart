import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/create_entry_page.dart';
import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/home_nav.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:anoworld/home/saves_tab.dart';
import 'package:anoworld/home/works_tab.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.pickImportDirectory,
  });

  /// Injectable folder picker for tests / platforms without a dialog.
  final Future<String?> Function()? pickImportDirectory;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeTab _tab = HomeTab.saves;
  final _savesSelection = LibrarySelectionController();
  final _worksSelection = LibrarySelectionController();
  final _savesKey = GlobalKey<SavesTabState>();
  final _worksKey = GlobalKey<WorksTabState>();

  @override
  void dispose() {
    _savesSelection.dispose();
    _worksSelection.dispose();
    super.dispose();
  }

  LibrarySelectionController get _activeSelection =>
      _tab == HomeTab.saves ? _savesSelection : _worksSelection;

  Future<void> _openRoute(Widget page) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (!mounted) return;
    await _savesKey.currentState?.reload();
    await _worksKey.currentState?.reload();
  }

  void _selectTab(int index) {
    final next = HomeTabNav.fromIndex(index);
    if (next == _tab) return;
    _savesSelection.exit();
    _worksSelection.exit();
    setState(() => _tab = next);
  }

  Future<void> _showCreateSheet() async {
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
            const AppText('开始创作', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceMd),
            AppButton(
              label: '新建空白作品',
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('blank'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '导入角色卡',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('card'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '粘贴故事',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('novel'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '分阶段提示词',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('staged'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '新建文件夹',
              variant: AppButtonVariant.ghost,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('folder'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '试用「雨夜投宿」',
              variant: AppButtonVariant.ghost,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('sample'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final works = _worksKey.currentState;
    switch (action) {
      case 'blank':
        await works?.createBlank();
      case 'card':
        await works?.openCreateEntry(CreateEntryKind.characterCard);
      case 'novel':
        await works?.openCreateEntry(CreateEntryKind.novel);
      case 'staged':
        await works?.openCreateEntry(CreateEntryKind.stagedPrompts);
      case 'folder':
        await works?.createFolder();
      case 'sample':
        await works?.addSample();
    }
  }

  Future<void> _showWorksMore() async {
    final works = _worksKey.currentState;
    final display = AppScope.libraryDisplayOf(context).prefs;
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
              label: '导入作品包',
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('import'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '新建文件夹',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('folder'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppListTile(
              title: '显示方式',
              subtitle: display.viewMode.label,
              icon: display.viewMode.icon,
              onTap: () => Navigator.of(ctx).pop('view_mode'),
            ),
            if (display.viewMode == LibraryViewMode.list) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppListTile(
                title: '头像形状',
                subtitle: display.avatarShape.label,
                icon: display.avatarShape.icon,
                onTap: () => Navigator.of(ctx).pop('avatar_shape'),
              ),
            ],
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '多选',
              variant: AppButtonVariant.ghost,
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop('select'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'import':
        await works?.importPack();
      case 'folder':
        await works?.createFolder();
      case 'view_mode':
        await works?.showViewModePicker();
      case 'avatar_shape':
        await works?.showAvatarShapePicker();
      case 'select':
        _worksSelection.enter(null);
        setState(() {});
    }
  }

  Widget _titleSwitcher({
    required String text,
    required String keyName,
    required bool forward,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(forward ? 0.08 : -0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Align(
        key: ValueKey(keyName),
        alignment: Alignment.centerLeft,
        child: AppText(text, role: AppTextRole.pageTitle, maxLines: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = _activeSelection;
    final selectionMode = selection.selectionMode;
    final works = _worksKey.currentState;
    final folderForward = works?.folderEnterForward ?? true;

    final titleText = selectionMode
        ? (selection.selectedCount == 0
            ? '选择项目'
            : '已选 ${selection.selectedCount} 项')
        : (_tab == HomeTab.saves ? '存档' : '作品');
    final titleKey = selectionMode
        ? 'select-${selection.selectedCount}'
        : (_tab == HomeTab.works
            ? 'works-${works?.browsePath.join('/') ?? ''}'
            : 'saves');

    final List<Widget> actions;
    if (selectionMode) {
      actions = [
        AppIconButton(
          icon: selection.hasSelection ? Icons.deselect : Icons.select_all,
          tooltip: selection.hasSelection ? '取消全选' : '全选',
          onPressed: () {
            if (_tab == HomeTab.saves) {
              _selectAllSaves();
            } else {
              _worksKey.currentState?.toggleSelectAllVisible();
            }
          },
        ),
        if (selection.hasSelection && _tab == HomeTab.works)
          AppIconButton(
            icon: Icons.drive_file_move_outline,
            tooltip: '移到文件夹',
            onPressed: () => _worksKey.currentState?.moveSelected(),
          ),
        if (selection.hasSelection)
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: '删除',
            onPressed: () async {
              if (_tab == HomeTab.saves) {
                await _savesKey.currentState?.deleteSelected();
              } else {
                await _worksKey.currentState?.deleteSelected();
              }
            },
          ),
      ];
    } else if (_tab == HomeTab.works) {
      actions = [
        AppIconButton(
          icon: Icons.folder_open,
          tooltip: '导入作品包',
          onPressed: () => _worksKey.currentState?.importPack(),
        ),
        AppIconButton(
          icon: Icons.more_vert,
          tooltip: '作品选项',
          onPressed: _showWorksMore,
        ),
        AppIconButton(
          icon: Icons.settings,
          tooltip: '设置',
          onPressed: () => _openRoute(const SettingsPage()),
        ),
      ];
    } else {
      actions = [
        AppIconButton(
          icon: Icons.checklist,
          tooltip: '多选',
          onPressed: () {
            _savesSelection.enter(null);
            setState(() {});
          },
        ),
        AppIconButton(
          icon: Icons.settings,
          tooltip: '设置',
          onPressed: () => _openRoute(const SettingsPage()),
        ),
      ];
    }

    return PopScope(
      canPop: !selectionMode && (works?.browsePath.isEmpty ?? true),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab == HomeTab.works &&
            (_worksKey.currentState?.handleSystemBack() ?? false)) {
          setState(() {});
          return;
        }
        if (selectionMode) {
          selection.exit();
          setState(() {});
        }
      },
      child: AppPage(
        title: titleText,
        titleWidget: _titleSwitcher(
          text: titleText,
          keyName: titleKey,
          forward: folderForward,
        ),
        onBack: selectionMode
            ? () {
                selection.exit();
                setState(() {});
              }
            : (_tab == HomeTab.works && (works?.browsePath.isNotEmpty ?? false)
                ? () {
                    _worksKey.currentState?.handleSystemBack();
                    setState(() {});
                  }
                : null),
        actions: actions,
        floatingActionButton: selectionMode
            ? null
            : Builder(
                builder: (context) {
                  final wide =
                      AppLayout.useRail(MediaQuery.sizeOf(context).width);
                  final bottomPad = wide
                      ? 0.0
                      : AppLayout.bottomNavHeight +
                          AppLayout.bottomNavBottomInset;
                  return Padding(
                    padding: EdgeInsets.only(bottom: bottomPad),
                    child: AppCircleButton(
                      icon: Icons.add,
                      tooltip: _tab == HomeTab.saves ? '去作品列表' : '开始创作',
                      variant: AppCircleButtonVariant.filled,
                      onPressed: () {
                        if (_tab == HomeTab.saves) {
                          _selectTab(HomeTab.works.tabIndex);
                        } else {
                          _showCreateSheet();
                        }
                      },
                    ),
                  );
                },
              ),
        body: AppNavShell(
          destinations: homeNavItems,
          selectedIndex: _tab.tabIndex,
          onDestinationSelected: _selectTab,
          railTopInset: 0,
          body: IndexedStack(
            index: _tab.tabIndex,
            children: [
              SavesTab(
                key: _savesKey,
                selection: _savesSelection,
                onBrowseWorks: () => _selectTab(HomeTab.works.tabIndex),
                onSelectionChromeChanged: () => setState(() {}),
              ),
              WorksTab(
                key: _worksKey,
                selection: _worksSelection,
                pickImportDirectory: widget.pickImportDirectory,
                onSelectionChromeChanged: () => setState(() {}),
                onBrowsePathChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectAllSaves() async {
    final saves = AppScope.savesOf(context);
    final projectsRepo = AppScope.projectsOf(context);
    final slots = await saves.listAll();
    final projects = await projectsRepo.listProjects();
    final known = {for (final p in projects) p.id};
    final ids = slots
        .where((slot) => known.contains(slot.projectId))
        .map((slot) => slot.projectId)
        .toList(growable: false);
    if (!mounted) return;
    _savesSelection.toggleSelectAll(ids);
    setState(() {});
  }
}
