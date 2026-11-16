import 'package:flutter/material.dart';

import '../../domain/settings/appearance_settings.dart';
import '../frame/window_controls.dart';
import 'app_continuous_input_border.dart';
import 'app_shapes.dart';
import 'app_ui_tokens.dart';
import 'theme_tokens.dart';

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

  factory AppColorTokens.fromThemeTokens(ThemeTokens tokens) => AppColorTokens(
        canvas: Color(tokens.editorSurface),
        onCanvas: Color(tokens.primaryText),
        primary: Color(tokens.accent),
        muted: Color(tokens.mutedText),
        surfaceRaised: Color(tokens.controlSurface),
        outlineSubtle: Color(tokens.border),
      );
}

/// Theme entry. Visual decisions are added here as pages need them.
abstract final class AppTheme {
  static const double titleBandHeight = 36;

  static const Size windowMinSize = Size(
    WindowControlMetrics.stripWidth + 160,
    titleBandHeight + 56 + 80,
  );

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceInline = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double radiusMd = 10;
  static const double pagePadding = spaceMd;
  static const double buttonHeight = 36;

  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 12,
  );

  /// Floor colors from Dark Modern (used when a fixed chrome color is needed).
  static final Color canvas = Color(ThemeTokens.defaults.editorSurface);
  static final Color onCanvas = Color(ThemeTokens.defaults.primaryText);
  static final Color primary = Color(ThemeTokens.defaults.accent);
  static final Color muted = Color(ThemeTokens.defaults.mutedText);
  static final Color surfaceRaised = Color(ThemeTokens.defaults.controlSurface);
  static final Color outlineSubtle = Color(ThemeTokens.defaults.border);

  static AppColorTokens tokensFor(ThemeTokens tokens) =>
      AppColorTokens.fromThemeTokens(tokens);

  static ThemeData dataFor({
    required Brightness brightness,
    AppearanceSettings? appearance,
  }) {
    final settings = appearance ?? AppearanceSettings();
    final themeTokens = settings.tokensFor(brightness);
    final tokens = tokensFor(themeTokens);
    final radius = settings.cornerRadius;
    final bodyPx = settings.fontSize;
    final fontFamily = settings.fontFamily;
    final ui = AppUiTokens(
      radius: radius,
      fontSize: bodyPx,
      fontFamily: fontFamily,
      fieldPadding: fieldPadding,
      spaceInline: spaceInline,
    );

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

    TextStyle sized(
      double baseSize, {
      FontWeight weight = FontWeight.w400,
      Color? color,
      double height = 1.35,
    }) {
      return TextStyle(
        fontSize: baseSize * (bodyPx / AppearanceUiRange.fontSizeDefault),
        fontWeight: weight,
        color: color,
        height: height,
        fontFamily: fontFamily,
      );
    }

    final shape = AppShapes.continuous(radius: radius);
    final radiusGeom = BorderRadius.circular(radius);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.canvas,
      dividerColor: tokens.outlineSubtle,
      fontFamily: fontFamily,
      extensions: <ThemeExtension<dynamic>>[ui],
      appBarTheme: AppBarTheme(
        toolbarHeight: titleBandHeight,
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.onCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 12,
      ),
      textTheme: TextTheme(
        titleLarge: sized(22, weight: FontWeight.w600, color: tokens.onCanvas),
        titleMedium:
            sized(16, weight: FontWeight.w600, color: tokens.onCanvas),
        bodyLarge: sized(15, color: tokens.onCanvas),
        bodyMedium: sized(14, color: tokens.onCanvas),
        bodySmall: sized(12, color: tokens.muted, height: 1.3),
        labelLarge:
            sized(14, weight: FontWeight.w600, color: tokens.onCanvas),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceRaised,
        isDense: true,
        contentPadding: fieldPadding,
        border: AppContinuousInputBorder(
          borderRadius: radiusGeom,
          borderSide: BorderSide(color: tokens.outlineSubtle),
        ),
        enabledBorder: AppContinuousInputBorder(
          borderRadius: radiusGeom,
          borderSide: BorderSide(color: tokens.outlineSubtle),
        ),
        focusedBorder: AppContinuousInputBorder(
          borderRadius: radiusGeom,
          borderSide: BorderSide(color: tokens.primary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceMd,
            vertical: spaceSm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceMd,
            vertical: spaceSm,
          ),
        ),
      ),
    );
  }

  static ThemeData get data => dataFor(brightness: Brightness.dark);

  static ThemeData light(AppearanceSettings appearance) =>
      dataFor(brightness: Brightness.light, appearance: appearance);

  static ThemeData dark(AppearanceSettings appearance) =>
      dataFor(brightness: Brightness.dark, appearance: appearance);
}
