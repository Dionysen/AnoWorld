import 'dart:typed_data';

import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/home/home_nav.dart';
import 'package:anoworld/home/home_tab_back.dart';
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
    this.pickImportPackage,
  });

  /// Injectable folder picker for tests / platforms without a dialog.
  final Future<String?> Function()? pickImportDirectory;

  /// Injectable `.anoworld` / zip bytes picker for tests.
  final Future<Uint8List?> Function()? pickImportPackage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeTab _tab = HomeTab.sessions;
  final _savesSelection = LibrarySelectionController();
  final _worksSelection = LibrarySelectionController();
  final _savesKey = GlobalKey<SavesTabState>();
  final _worksKey = GlobalKey<WorksTabState>();
  final _playKey = GlobalKey<PlayModesTabState>();
  final _meKey = GlobalKey<MeTabState>();
  bool _assistantSynced = false;

  @override
  void dispose() {
    _savesSelection.dispose();
    _worksSelection.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assistantSynced) return;
    _assistantSynced = true;
    _syncAssistantVisibility();
  }

  LibrarySelectionController? get _activeSelection => switch (_tab) {
        HomeTab.sessions => _savesSelection,
        HomeTab.stories => _worksSelection,
        HomeTab.playModes || HomeTab.me => null,
      };

  void _syncAssistantVisibility() {
    final selectionMode = _activeSelection?.selectionMode ?? false;
    final show = _tab == HomeTab.stories && !selectionMode;
    AppScope.createAssistantOf(context).setHomeStories(show);
  }

  void _selectTab(int index) {
    final next = HomeTabNav.fromIndex(index);
    if (next == _tab) return;
    _savesSelection.exit();
    _worksSelection.exit();
    setState(() => _tab = next);
    _syncAssistantVisibility();
    if (next == HomeTab.sessions) {
      _savesKey.currentState?.reload();
    }
  }

  void _onChromeChanged() {
    setState(() {});
    _syncAssistantVisibility();
  }

  /// 会话里的「打开故事」：故事页只属于故事分区，切过去并选中那一本。
  Future<void> _openStoryInStories(String projectId) async {
    if (_tab != HomeTab.stories) {
      _savesSelection.exit();
      _worksSelection.exit();
      setState(() => _tab = HomeTab.stories);
      _syncAssistantVisibility();
    }
    await _worksKey.currentState?.revealProject(projectId);
  }

  /// The active tab's inner state (selection / folder / detail) owns back.
  HomeTabBack? get _activeTabBack => switch (_tab) {
    HomeTab.sessions => _savesKey.currentState,
    HomeTab.stories => _worksKey.currentState,
    HomeTab.playModes => _playKey.currentState,
    HomeTab.me => _meKey.currentState,
  };

  @override
  Widget build(BuildContext context) {
    final backHandler = _activeTabBack;

    return PopScope(
      canPop: !(backHandler?.canGoBack ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (backHandler?.handleSystemBack() ?? false) {
          setState(() {});
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // No page title on home — search / toolbars live in each tab body.
          return AppPage(
            title: '',
            showTitle: false,
            body: AppNavShell(
              destinations: homeNavItems(context.strings),
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
                    onOpenStory: _openStoryInStories,
                    onChromeChanged: _onChromeChanged,
                  ),
                  WorksTab(
                    key: _worksKey,
                    selection: _worksSelection,
                    pickImportDirectory: widget.pickImportDirectory,
                    pickImportPackage: widget.pickImportPackage,
                    onChromeChanged: _onChromeChanged,
                    onBrowsePathChanged: (_) => setState(() {}),
                  ),
                  PlayModesTab(key: _playKey, onChromeChanged: _onChromeChanged),
                  MeTab(key: _meKey, onChromeChanged: _onChromeChanged),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
