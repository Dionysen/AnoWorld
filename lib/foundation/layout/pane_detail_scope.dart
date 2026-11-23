import 'package:flutter/widgets.dart';

/// Marks a subtree as the detail pane of a master-detail split.
///
/// Pages embedded there sit *inside* the shell chrome, and the list beside them
/// is the way back, so [AppPage] skips the window chrome band, the horizontal
/// safe-area inset (already applied by the shell) and its own back button.
/// Everything else — title, actions, body — renders unchanged.
class PaneDetailScope extends InheritedWidget {
  const PaneDetailScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaneDetailScope>()?.active ??
      false;

  @override
  bool updateShouldNotify(PaneDetailScope oldWidget) =>
      oldWidget.active != active;
}
