import 'package:flutter/material.dart';

import '../../domain/settings/appearance_settings.dart';
import '../frame/window_controls.dart';

class AppColorTokens {
  const AppColorTokens({
    required this.canvas,
    required this.onCanvas,
    required this.primary,
    required this.muted,
    required this.surfaceRaised,
    required this.outlineSubtle,
  });

  final Color canvas;
  final Color onCanvas;
  final Color primary;
  final Color muted;
  final Color surfaceRaised;
  final Color outlineSubtle;
}

/// Theme entry. Visual decisions are added here as pages need them.
abstract final class AppTheme {
  /// Immersive title band height on desktop and under the status bar on mobile.
  static const double titleBandHeight = 36;

  /// Smallest desktop client size that still fits chrome without overflow.
  static const Size windowMinSize = Size(
    WindowControlMetrics.stripWidth + 160,
    titleBandHeight + 56 + 80,
  );

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double radiusMd = 10;
  static const double pagePadding = spaceMd;

  /// Default dark tokens (午夜) — used by chrome that needs a fixed floor.
  static const Color canvas = Color(0xFF0B0C12);
  static const Color onCanvas = Color(0xFFE8E6F0);
  static const Color primary = Color(0xFF98A6F5);
  static const Color muted = Color(0xFF9A96A8);
  static const Color surfaceRaised = Color(0xFF14151F);
  static const Color outlineSubtle = Color(0xFF2A2B36);

  static AppColorTokens tokensFor({
    required AppThemePreset preset,
    required Brightness brightness,
  }) {
    return switch ((preset, brightness)) {
      (AppThemePreset.midnight, Brightness.dark) => const AppColorTokens(
          canvas: Color(0xFF0B0C12),
          onCanvas: Color(0xFFE8E6F0),
          primary: Color(0xFF98A6F5),
          muted: Color(0xFF9A96A8),
          surfaceRaised: Color(0xFF14151F),
          outlineSubtle: Color(0xFF2A2B36),
        ),
      (AppThemePreset.midnight, Brightness.light) => const AppColorTokens(
          canvas: Color(0xFFF3F4F8),
          onCanvas: Color(0xFF16171F),
          primary: Color(0xFF5B6BD6),
          muted: Color(0xFF6B6F80),
          surfaceRaised: Color(0xFFFFFFFF),
          outlineSubtle: Color(0xFFD8DBE6),
        ),
      (AppThemePreset.slate, Brightness.dark) => const AppColorTokens(
          canvas: Color(0xFF12141A),
          onCanvas: Color(0xFFE6E9F0),
          primary: Color(0xFF7DD3C0),
          muted: Color(0xFF9AA3B2),
          surfaceRaised: Color(0xFF1A1D26),
          outlineSubtle: Color(0xFF2E3440),
        ),
      (AppThemePreset.slate, Brightness.light) => const AppColorTokens(
          canvas: Color(0xFFEEF1F5),
          onCanvas: Color(0xFF1B1F27),
          primary: Color(0xFF0F8F7A),
          muted: Color(0xFF5E6675),
          surfaceRaised: Color(0xFFFFFFFF),
          outlineSubtle: Color(0xFFCED5DF),
        ),
      (AppThemePreset.mist, Brightness.dark) => const AppColorTokens(
          canvas: Color(0xFF151820),
          onCanvas: Color(0xFFE9ECF4),
          primary: Color(0xFF8AB4FF),
          muted: Color(0xFFA0A7B8),
          surfaceRaised: Color(0xFF1C2030),
          outlineSubtle: Color(0xFF30364A),
        ),
      (AppThemePreset.mist, Brightness.light) => const AppColorTokens(
          canvas: Color(0xFFF7F8FB),
          onCanvas: Color(0xFF1A1C24),
          primary: Color(0xFF3D6FE8),
          muted: Color(0xFF6A7184),
          surfaceRaised: Color(0xFFFFFFFF),
          outlineSubtle: Color(0xFFD5DAE6),
        ),
    };
  }

  static ThemeData dataFor({
    required AppThemePreset preset,
    required Brightness brightness,
  }) {
    final tokens = tokensFor(preset: preset, brightness: brightness);
    final scheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            surface: tokens.canvas,
            onSurface: tokens.onCanvas,
            primary: tokens.primary,
            onPrimary: tokens.canvas,
            onSurfaceVariant: tokens.muted,
            surfaceContainerHighest: tokens.surfaceRaised,
            outline: tokens.outlineSubtle,
          )
        : ColorScheme.light(
            surface: tokens.canvas,
            onSurface: tokens.onCanvas,
            primary: tokens.primary,
            onPrimary: Colors.white,
            onSurfaceVariant: tokens.muted,
            surfaceContainerHighest: tokens.surfaceRaised,
            outline: tokens.outlineSubtle,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.canvas,
      dividerColor: tokens.outlineSubtle,
      appBarTheme: AppBarTheme(
        toolbarHeight: titleBandHeight,
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.onCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 12,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: tokens.onCanvas,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: tokens.onCanvas,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.35,
          color: tokens.onCanvas,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: tokens.onCanvas,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.3,
          color: tokens.muted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tokens.onCanvas,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceSm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: tokens.outlineSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: tokens.outlineSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: tokens.primary),
        ),
      ),
    );
  }

  /// Backward-compatible default (午夜 · 深色).
  static ThemeData get data => dataFor(
        preset: AppThemePreset.midnight,
        brightness: Brightness.dark,
      );

  static ThemeData light(AppThemePreset preset) =>
      dataFor(preset: preset, brightness: Brightness.light);

  static ThemeData dark(AppThemePreset preset) =>
      dataFor(preset: preset, brightness: Brightness.dark);
}
