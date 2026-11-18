import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/create_assistant_host.dart';
import 'package:anoworld/home/home_nav.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:anoworld/home/me_tab.dart';
import 'package:anoworld/home/play_modes_tab.dart';
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
  HomeTab _tab = HomeTab.sessions;
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

  LibrarySelectionController? get _activeSelection => switch (_tab) {
        HomeTab.sessions => _savesSelection,
        HomeTab.stories => _worksSelection,
        HomeTab.playModes || HomeTab.me => null,
      };

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
    if (next == HomeTab.sessions) {
      _savesKey.currentState?.reload();
    }
  }

  Widget _titleSwitcher(String text) {
    // Key by visible text only — folder enter/exit keeps「故事」and must not
    // remount / flash. Real title changes (分区标题、多选计数) fade.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Align(
        key: ValueKey<String>(text),
        alignment: Alignment.centerLeft,
        child: AppText(text, role: AppTextRole.pageTitle, maxLines: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = _activeSelection;
    final selectionMode = selection?.selectionMode ?? false;
    final works = _worksKey.currentState;

    final hideStoriesTitle = _tab == HomeTab.stories && !selectionMode;
    final titleText = selectionMode && selection != null
        ? (selection.selectedCount == 0
            ? '选择项目'
            : '已选 ${selection.selectedCount} 项')
        : switch (_tab) {
            HomeTab.sessions => '会话',
            HomeTab.stories => '故事',
            HomeTab.playModes => '玩法',
            HomeTab.me => '我',
          };

    final List<Widget> actions;
    if (selectionMode && selection != null) {
      actions = [
        AppIconButton(
          icon: selection.hasSelection ? Icons.deselect : Icons.select_all,
          tooltip: selection.hasSelection ? '取消全选' : '全选',
          onPressed: () {
            if (_tab == HomeTab.sessions) {
              _selectAllSaves();
            } else {
              _worksKey.currentState?.toggleSelectAllVisible();
            }
          },
        ),
        if (selection.hasSelection && _tab == HomeTab.stories)
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
              if (_tab == HomeTab.sessions) {
                await _savesKey.currentState?.deleteSelected();
              } else {
                await _worksKey.currentState?.deleteSelected();
              }
            },
          ),
      ];
    } else if (_tab == HomeTab.me) {
      actions = [
        AppIconButton(
          icon: Icons.settings_outlined,
          tooltip: '设置',
          onPressed: () => _openRoute(const SettingsPage()),
        ),
      ];
    } else if (_tab == HomeTab.sessions) {
      actions = [
        AppIconButton(
          icon: Icons.checklist,
          tooltip: '多选',
          onPressed: () {
            _savesSelection.enter(null);
            setState(() {});
          },
        ),
      ];
    } else {
      actions = const [];
    }

    return PopScope(
      canPop: !selectionMode && (works?.browsePath.isEmpty ?? true),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab == HomeTab.stories &&
            (_worksKey.currentState?.handleSystemBack() ?? false)) {
          setState(() {});
          return;
        }
        if (selectionMode && selection != null) {
          selection.exit();
          setState(() {});
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shell = AppNavShell(
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
                  onBrowseWorks: () => _selectTab(HomeTab.stories.tabIndex),
                  onSelectionChromeChanged: () => setState(() {}),
                ),
                WorksTab(
                  key: _worksKey,
                  selection: _worksSelection,
                  pickImportDirectory: widget.pickImportDirectory,
                  onSelectionChromeChanged: () => setState(() {}),
                  onBrowsePathChanged: (_) => setState(() {}),
                ),
                const PlayModesTab(),
                const MeTab(),
              ],
            ),
          );

          final storiesChrome = _tab == HomeTab.stories && !selectionMode;
          final body =
              storiesChrome ? CreateAssistantHost(child: shell) : shell;

          return AppPage(
            title: titleText,
            titleWidget: hideStoriesTitle ? null : _titleSwitcher(titleText),
            showTitle: !hideStoriesTitle,
            onBack: selectionMode && selection != null
                ? () {
                    selection.exit();
                    setState(() {});
                  }
                : null,
            actions: actions,
            body: body,
          );
        },
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
        .map((slot) => slot.id)
        .toList(growable: false);
    if (!mounted) return;
    _savesSelection.toggleSelectAll(ids);
    setState(() {});
  }
}
