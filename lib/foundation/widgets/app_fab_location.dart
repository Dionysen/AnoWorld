import 'package:flutter/material.dart';

import '../layout/app_layout.dart';
import '../theme/app_theme.dart';
import 'app_circle_button.dart';

/// Scaffold FAB anchors for layouts with [AppNavShell] bottom chrome.
abstract final class AppFabLocation {
  /// Lift above the compact bottom nav (body padding already reserves clearance;
  /// this aligns the FAB with that inset + the physical nav overlay).
  static const aboveCompactBottomNav = _AboveCompactBottomNavFabLocation();
}

class _AboveCompactBottomNavFabLocation
    extends StandardFabLocation
    with FabEndOffsetX, FabFloatOffsetY {
  const _AboveCompactBottomNavFabLocation();

  /// Matches [AppNavShell] compact [barClearance] + FAB diameter slack.
  static const double _lift = AppLayout.bottomNavHeight +
      AppLayout.bottomNavBottomInset +
      AppTheme.spaceSm +
      (AppCircleButton.fabDiameter - AppCircleButton.diameter) / 2;

  @override
  double getOffsetY(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    return super.getOffsetY(scaffoldGeometry, adjustment) - _lift;
  }
}