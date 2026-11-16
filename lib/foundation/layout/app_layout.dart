/// Responsive chrome breakpoints (NativeTavern-inspired).
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
