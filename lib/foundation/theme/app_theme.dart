import 'package:flutter/material.dart';

import '../frame/window_controls.dart';

/// Theme entry. Visual decisions are added here as pages need them.
abstract final class AppTheme {
  /// Immersive title band height on desktop and under the status bar on mobile.
  static const double titleBandHeight = 36;

  /// Smallest desktop client size that still fits chrome without overflow.
  ///
  /// Width covers window buttons plus a short title. Height covers the title
  /// band plus a slim body strip. Pages must still tolerate smaller bounds by
  /// hiding controls rather than overflowing.
  static const Size windowMinSize = Size(
    WindowControlMetrics.stripWidth + 160,
    titleBandHeight + 80,
  );

  /// Single immersive canvas: page body and title band share this fill.
  static const Color canvas = Color(0xFF0B0C12);
  static const Color onCanvas = Color(0xFFE8E6F0);
  static const Color primary = Color(0xFF98A6F5);

  static ThemeData get data {
    final base = ColorScheme.dark(
      surface: canvas,
      onSurface: onCanvas,
      primary: primary,
      onPrimary: canvas,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        toolbarHeight: titleBandHeight,
        backgroundColor: canvas,
        foregroundColor: onCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 12,
      ),
    );
  }
}
