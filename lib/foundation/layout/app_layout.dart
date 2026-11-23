/// Responsive chrome breakpoints (NativeTavern-inspired).
///
/// Same width ⇒ same chrome on every platform (desktop portrait ≡ phone).
/// Do not branch nav on [TargetPlatform].
///
/// Window/status chrome is background-only; software titles live in
/// [AppPage]'s page title bar ([AppPage.showTitle]). Home hubs hide that bar.
///
/// - Compact (portrait / narrow): bottom navigation, single content layer.
/// - Expanded (landscape / wide): left rail; optional secondary list + detail.
abstract final class AppLayout {
  /// Width at which the shell switches from bottom nav to left rail.
  static const double railBreakpoint = 600;

  /// Primary rail / bottom-nav icon column width.
  static const double railWidth = 72;

  /// Settings / list pane beside the rail.
  static const double secondaryPaneWidth = 220;

  /// Master-detail split (content list | detail), on top of the rail.
  ///
  /// Distinct from [secondaryPaneWidth]: there the extra pane is a bookkeeping
  /// section list, while here pane 2 is the real content list, so both panes
  /// need room to breathe. Same order as `NativeTavern`'s `MasterDetailBranch`.
  static const double masterPaneMinWidth = 360;
  static const double masterPaneDefaultWidth = 400;

  /// Draggable hit target between master and detail (hairline sits centered).
  static const double paneResizeHandleWidth = 6;

  /// Master + handle + detail must all fit before the split turns on.
  static double get masterDetailContentMinWidth =>
      masterPaneMinWidth + paneResizeHandleWidth + detailPaneMinWidth;

  /// [contentWidth] is the body width left after the rail (and any nav list).
  static bool useMasterDetail(double contentWidth) =>
      contentWidth >= masterDetailContentMinWidth;

  /// Keeps both panes above their minimums while the divider is dragged.
  static double clampMasterPaneWidth({
    required double desired,
    required double contentWidth,
  }) {
    final maxPane =
        contentWidth - detailPaneMinWidth - paneResizeHandleWidth;
    if (maxPane <= masterPaneMinWidth) return masterPaneMinWidth;
    return desired.clamp(masterPaneMinWidth, maxPane).toDouble();
  }

  /// Minimum width reserved for the detail / page body in three-pane mode.
  static const double detailPaneMinWidth = 320;

  static const double paneDividerWidth = 1;

  /// Compact bottom nav: floating capsule (iOS-style), not edge-flush.
  static const double bottomNavHeight = 56;
  static const double bottomNavHorizontalInset = 16;
  static const double bottomNavBottomInset = 10;

  /// Frosted-glass blur for the capsule (`BackdropFilter` sigma).
  static const double bottomNavBlurSigma = 28;

  /// Content width (after rail) needed for secondary + detail.
  static double get threePaneContentMinWidth =>
      secondaryPaneWidth + paneDividerWidth + detailPaneMinWidth;

  static bool useRail(double width) => width >= railBreakpoint;

  /// Three layers: rail | secondary | detail.
  static bool useThreePane({
    required double shellWidth,
    required bool hasSecondary,
  }) {
    if (!hasSecondary || !useRail(shellWidth)) return false;
    final contentWidth = shellWidth - railWidth - paneDividerWidth;
    return contentWidth >= threePaneContentMinWidth;
  }
}

enum AppChromeMode { compact, expanded }

extension AppChromeModeX on AppChromeMode {
  bool get isCompact => this == AppChromeMode.compact;
  bool get isExpanded => this == AppChromeMode.expanded;
}

AppChromeMode chromeModeForWidth(double width) =>
    AppLayout.useRail(width) ? AppChromeMode.expanded : AppChromeMode.compact;
