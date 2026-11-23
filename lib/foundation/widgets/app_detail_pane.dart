import 'package:flutter/material.dart';

import '../layout/pane_detail_scope.dart';

/// Owns the navigation stack of one master-detail detail column.
///
/// The column shows the selected item's real page (the same page a narrow
/// window pushes full-screen), and any page opened from it — editor, play
/// session, settings — is pushed **inside** the column. The master list keeps
/// its place, so the third column behaves like the single-column stack it
/// replaces instead of covering the whole window.
class AppDetailPaneController extends ChangeNotifier {
  NavigatorState? _navigator;

  bool _notifyScheduled = false;
  bool _disposed = false;

  /// A page sits on top of the selected item.
  bool get canPop => _navigator?.canPop() ?? false;

  /// Pops the top pane route; false when only the selected item is showing.
  bool pop() {
    final navigator = _navigator;
    if (navigator == null || !navigator.canPop()) return false;
    navigator.pop();
    return true;
  }

  /// Called by the mounted pane; remounting (new selection) replaces it.
  void _attach(NavigatorState navigator) {
    _navigator = navigator;
  }

  void _detach() {
    _navigator = null;
  }

  /// Navigator observers fire mid-frame, so listeners rebuild on the next
  /// frame instead of mutating the tree while it is being built.
  void _handleStackChanged() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Detail column host: renders [root] and keeps deeper pages in the column.
///
/// The host gives this widget the selected item's key, so switching selection
/// remounts the pane and the old stack (an editor for the previous story) goes
/// away with it.
class AppDetailPane extends StatefulWidget {
  const AppDetailPane({
    super.key,
    required this.root,
    required this.controller,
  });

  /// Page for the current selection, sitting at the bottom of the stack.
  ///
  /// Rebuilt by the host, so refreshed data and callbacks reach it without
  /// resetting navigation.
  final Widget root;

  /// Lives with the tab (not with the selection), so back handling keeps
  /// working across selections.
  final AppDetailPaneController controller;

  @override
  State<AppDetailPane> createState() => _AppDetailPaneState();
}

class _AppDetailPaneState extends State<AppDetailPane> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  late final NavigatorObserver _observer = _PaneStackObserver(
    () => widget.controller._handleStackChanged(),
  );

  @override
  void initState() {
    super.initState();
    // The controller drives back handling from outside this subtree; attach
    // once the navigator exists (a new selection mounts a new one).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = _navigatorKey.currentState;
      if (navigator != null) widget.controller._attach(navigator);
    });
  }

  @override
  void dispose() {
    widget.controller._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaneDetailScope(
      active: true,
      child: HeroControllerScope.none(
        child: _PaneRootScope(
          root: widget.root,
          child: Navigator(
            key: _navigatorKey,
            observers: <NavigatorObserver>[_observer],
            onGenerateRoute: _buildRoute,
          ),
        ),
      ),
    );
  }

  /// Bottom route: no transition, it *is* the column's content.
  Route<void> _buildRoute(RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          const _PaneRootPage(),
    );
  }
}

/// Keeps the bottom route showing the host's current [AppDetailPane.root].
///
/// Widgets are rebuilt by the host every selection/refresh; the route itself
/// stays put, so only this dependency carries the new instance in.
class _PaneRootScope extends InheritedWidget {
  const _PaneRootScope({required this.root, required super.child});

  final Widget root;

  static Widget of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PaneRootScope>()!.root;

  @override
  bool updateShouldNotify(_PaneRootScope oldWidget) =>
      oldWidget.root != root;
}

class _PaneRootPage extends StatelessWidget {
  const _PaneRootPage();

  @override
  Widget build(BuildContext context) => _PaneRootScope.of(context);
}

class _PaneStackObserver extends NavigatorObserver {
  _PaneStackObserver(this._onChanged);

  final VoidCallback _onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _onChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _onChanged();
}
