/// A home tab body that can unwind its own inner state before the shell pops.
///
/// [HomePage] asks the active tab first, so a system back deselects the detail
/// pane / exits selection / leaves a folder instead of closing the window.
abstract interface class HomeTabBack {
  /// True while a system back must stay inside the tab.
  bool get canGoBack;

  /// Consumes one back step; returns false when there was nothing to unwind.
  bool handleSystemBack();
}
