import 'package:flutter/material.dart';

/// Theme entry. Visual decisions are added here as pages need them.
abstract final class AppTheme {
  /// Immersive title band height on desktop and under the status bar on mobile.
  static const double titleBandHeight = 36;

  static const Color _surface = Color(0xFF12141C);
  static const Color _canvas = Color(0xFF0B0C12);
  static const Color _onSurface = Color(0xFFE8E6F0);
  static const Color _primary = Color(0xFF98A6F5);

  static ThemeData get data {
    final base = ColorScheme.dark(
      surface: _surface,
      onSurface: _onSurface,
      primary: _primary,
      onPrimary: _canvas,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: _canvas,
      appBarTheme: const AppBarTheme(
        toolbarHeight: titleBandHeight,
        backgroundColor: _surface,
        foregroundColor: _onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 12,
      ),
    );
  }
}
