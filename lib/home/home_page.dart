import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/home/create_assistant_host.dart';
import 'package:anoworld/home/home_nav.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:anoworld/home/me_tab.dart';
import 'package:anoworld/home/play_modes_tab.dart';
import 'package:anoworld/home/saves_tab.dart';
import 'package:anoworld/home/works_tab.dart';
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

  @override
  Widget build(BuildContext context) {
    final selection = _activeSelection;
    final selectionMode = selection?.selectionMode ?? false;
    final works = _worksKey.currentState;

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

          // No page title on home — search / toolbars live in each tab body.
          return AppPage(
            title: '',
            showTitle: false,
            body: body,
          );
        },
      ),
    );
  }
}
