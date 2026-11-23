import 'package:flutter/material.dart';

/// Marker for routes that belong to the story / create-assistant chrome.
abstract interface class StoryChromeRoute {}

/// Horizontal slide page route (push from right, pop to right).
///
/// Use for parent ↔ child page navigations. Bottom-nav tab switches stay on
/// [IndexedStack] and must not use this.
class AppSlidePageRoute<T> extends PageRouteBuilder<T> {
  AppSlidePageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
        );
}

/// Story-flow slide route — keeps the create-assistant overlay visible.
class AppStorySlidePageRoute<T> extends AppSlidePageRoute<T>
    implements StoryChromeRoute {
  AppStorySlidePageRoute({
    required super.builder,
    super.settings,
  });
}

Widget _slideTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final enter = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
  );
  final exit = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.28, 0),
  ).animate(
    CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic),
  );

  return SlideTransition(
    position: exit,
    child: SlideTransition(
      position: enter,
      child: child,
    ),
  );
}

/// Pushes [page] with the shared horizontal slide transition.
///
/// [fullscreen] targets the root navigator, so a page opened from a
/// master-detail detail column covers the whole window instead of staying in
/// the column. Play stages always do that; harmless in single-column layouts,
/// where the root navigator is the nearest one anyway.
Future<T?> pushAppSlide<T extends Object?>(
  BuildContext context,
  Widget page, {
  bool storyChrome = false,
  bool fullscreen = false,
}) {
  final route = storyChrome
      ? AppStorySlidePageRoute<T>(builder: (_) => page)
      : AppSlidePageRoute<T>(builder: (_) => page);
  final navigator = fullscreen
      ? Navigator.of(context, rootNavigator: true)
      : Navigator.of(context);
  return navigator.push<T>(route);
}
