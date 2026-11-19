import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Visibility for the create-assistant overlay (stories tab + story subpages).
///
/// The host stays mounted; only [visible] toggles. Opaque non-story [PageRoute]s
/// (play, settings-from-story, etc.) temporarily cover it.
class CreateAssistantController extends ChangeNotifier {
  bool _homeStories = false;
  int _storyRouteCount = 0;
  int _coverCount = 0;
  final Set<Route<dynamic>> _popups = <Route<dynamic>>{};

  bool get visible =>
      (_homeStories || _storyRouteCount > 0) && _coverCount == 0;

  /// A sheet / dialog is on top of the page. The root overlay puts the
  /// assistant chrome above every route, so it must stop painting instead of
  /// covering the popup (story picker, confirmations, menus).
  bool get modalOpen => _popups.isNotEmpty;

  bool get homeStories => _homeStories;

  void setHomeStories(bool value) {
    if (_homeStories == value) return;
    _homeStories = value;
    AppLog.instance.info(
      value ? '创作助手：故事页显示' : '创作助手：离开故事页隐藏',
      tag: 'create.assistant',
    );
    notifyListeners();
  }

  void onRoutePushed(Route<dynamic> route) {
    if (route is StoryChromeRoute) {
      _storyRouteCount++;
      _notify();
      return;
    }
    if (route is PopupRoute) {
      _popups.add(route);
      _notify();
      return;
    }
    if (_shouldCover(route)) {
      _coverCount++;
      _notify();
    }
  }

  void onRoutePopped(Route<dynamic> route) {
    if (route is StoryChromeRoute) {
      if (_storyRouteCount > 0) _storyRouteCount--;
      _notify();
      return;
    }
    if (_popups.remove(route)) {
      _notify();
      return;
    }
    if (_shouldCover(route) && _coverCount > 0) {
      _coverCount--;
      _notify();
    }
  }

  void onRouteRemoved(Route<dynamic> route) => onRoutePopped(route);

  bool _shouldCover(Route<dynamic> route) {
    if (route is! PageRoute || !route.opaque) return false;
    return _homeStories || _storyRouteCount > 0;
  }

  void _notify() {
    // NavigatorObserver callbacks can fire during build/layout.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
}

/// Tracks story / opaque page routes for [CreateAssistantController].
class CreateAssistantNavigatorObserver extends NavigatorObserver {
  CreateAssistantNavigatorObserver(
    this.controller, {
    this.onStackChanged,
  });

  final CreateAssistantController controller;
  final VoidCallback? onStackChanged;

  void _afterStackChange() {
    onStackChanged?.call();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.onRoutePushed(route);
    _afterStackChange();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.onRoutePopped(route);
    _afterStackChange();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.onRouteRemoved(route);
    _afterStackChange();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) controller.onRouteRemoved(oldRoute);
    if (newRoute != null) controller.onRoutePushed(newRoute);
    _afterStackChange();
  }
}
