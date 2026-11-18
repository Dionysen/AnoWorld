import 'package:flutter/material.dart';

import '../../domain/settings/appearance_settings.dart';
import '../frame/window_controls.dart';
import 'app_chat_colors.dart';
import 'app_continuous_input_border.dart';
import 'app_shapes.dart';
import 'app_ui_tokens.dart';
import 'theme_tokens.dart';

class AppColorTokens {
  const AppColorTokens({
    required this.canvas,
    required this.onCanvas,
    required this.sidebar,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.muted,
    required this.surfaceRaised,
    required this.outlineSubtle,
    required this.divider,
    required this.cursor,
  });

  final Color canvas;
  final Color onCanvas;
  final Color sidebar;
  /// [ThemeTokens.accent] — highlights, selection, primary actions.
  final Color primary;
  /// [ThemeTokens.secondaryAccent] — section/action contrast.
  final Color secondary;
  /// [ThemeTokens.tertiaryAccent] — extra section contrast / dialogue tint.
  final Color tertiary;
  final Color muted;
  final Color surfaceRaised;
  final Color outlineSubtle;
  final Color divider;
  final Color cursor;

  factory AppColorTokens.fromThemeTokens(ThemeTokens tokens) => AppColorTokens(
        canvas: Color(tokens.editorSurface),
        onCanvas: Color(tokens.primaryText),
        sidebar: Color(tokens.sidebarSurface),
        primary: Color(tokens.accent),
        secondary: Color(tokens.secondaryAccent),
        tertiary: Color(tokens.tertiaryAccent),
        muted: Color(tokens.mutedText),
        surfaceRaised: Color(tokens.controlSurface),
        outlineSubtle: Color(tokens.border),
        divider: Color(tokens.divider),
        cursor: Color(tokens.cursor),
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
  /// Vertical gap between stacked controls in the same section/group.
  /// Flat list rows use hairline dividers instead of this gap.
  static const double spaceGroup = 6;
  static const double spaceInline = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double radiusMd = 10;
  static const double pagePadding = spaceMd;

  /// Horizontal inset for [AppPage] title chrome (back / title / actions).
  /// Tighter than [pagePadding] so side icon buttons sit closer to the edges.
  static const double titleChromePadding = spaceSm;
  static const double buttonHeight = 36;

  /// Press-in scale for tappable chrome ([AppPressScale], bottom nav, rail).
  static const double pressScale = 0.92;

  /// Duration of the press-in / release scale animation.
  static const Duration pressScaleDuration = Duration(milliseconds: 120);

  /// Elevation for raised surfaces (cards that should cast a shadow).
  static const double surfaceElevation = 8;

  /// Flat list row hairline: theme [dividerColor] lightly lifted with
  /// [onSurface] so dark packs stay readable without looking heavy.
  static Color listHairline(BuildContext context) {
    final theme = Theme.of(context);
    final boost = theme.brightness == Brightness.dark ? 0.04 : 0.028;
    return Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: boost),
      theme.dividerColor,
    );
  }

  /// Side/bottom inset for floating sheets (narrower than the page).
  static const double sheetInset = spaceMd;

  /// Max width so sheets stay a clear layer on wide windows.
  static const double sheetMaxWidth = 400;

  /// [AppSheetSize.half] — about half the screen.
  static const double sheetHalfHeightFactor = 0.5;

  /// [AppSheetSize.full] — nearly fill the screen; also caps compact sheets.
  static const double sheetFullHeightFactor = 0.9;

  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 12,
  );

  /// Floor colors from Dark Modern (used when a fixed chrome color is needed).
  static final Color canvas = Color(ThemeTokens.defaults.editorSurface);
  static final Color onCanvas = Color(ThemeTokens.defaults.primaryText);
  static final Color primary = Color(ThemeTokens.defaults.accent);
  static final Color secondary =
      Color(ThemeTokens.defaults.secondaryAccent);
  static final Color tertiary = Color(ThemeTokens.defaults.tertiaryAccent);
  static final Color muted = Color(ThemeTokens.defaults.mutedText);
  static final Color surfaceRaised = Color(ThemeTokens.defaults.controlSurface);
  static final Color outlineSubtle = Color(ThemeTokens.defaults.border);

  static AppColorTokens tokensFor(ThemeTokens tokens) =>
      AppColorTokens.fromThemeTokens(tokens);

  /// Maps NT semantic accents into Material [ColorScheme] roles.
  static ColorScheme colorSchemeFor(
    AppColorTokens tokens, {
    required Brightness brightness,
  }) {
    final selected = Color.alphaBlend(
      tokens.primary.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12),
      tokens.sidebar,
    );
    final tertiaryContainer = Color.alphaBlend(
      tokens.tertiary.withValues(
        alpha: brightness == Brightness.dark ? 0.28 : 0.18,
      ),
      tokens.canvas,
    );
    final base = brightness == Brightness.dark
        ? ColorScheme.dark(surface: tokens.canvas)
        : ColorScheme.light(surface: tokens.canvas);
    final nestedSurface = Color.lerp(
      tokens.canvas,
      tokens.surfaceRaised,
      brightness == Brightness.dark ? 0.42 : 0.62,
    )!;
    return base.copyWith(
      primary: tokens.primary,
      onPrimary: Colors.white,
      secondary: tokens.secondary,
      onSecondary: Colors.white,
      tertiary: tokens.tertiary,
      onTertiary: Colors.white,
      secondaryContainer: selected,
      onSecondaryContainer: tokens.onCanvas,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: tokens.onCanvas,
      surface: tokens.canvas,
      onSurface: tokens.onCanvas,
      surfaceContainerLowest: tokens.sidebar,
      surfaceContainer: nestedSurface,
      surfaceContainerHighest: tokens.surfaceRaised,
      onSurfaceVariant: tokens.muted,
      outline: tokens.outlineSubtle,
      outlineVariant: tokens.divider,
    );
  }

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

    final scheme = colorSchemeFor(tokens, brightness: brightness);
    final focusBorder = Color.alphaBlend(
      tokens.primary.withValues(alpha: 0.5),
      tokens.outlineSubtle,
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
      dividerColor: tokens.divider,
      fontFamily: fontFamily,
      extensions: <ThemeExtension<dynamic>>[
        ui,
        AppChatColors.fromThemeTokens(themeTokens),
      ],
      splashColor: tokens.primary.withValues(alpha: 0.14),
      highlightColor: tokens.primary.withValues(alpha: 0.08),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.primary;
          }
          return null;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return null;
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.cursor,
        selectionColor: tokens.primary.withValues(alpha: 0.35),
        selectionHandleColor: tokens.cursor,
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: titleBandHeight,
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.onCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 12,
        titleTextStyle: sized(16, weight: FontWeight.w600, color: tokens.onCanvas),
      ),
      textTheme: TextTheme(
        headlineSmall:
            sized(24, weight: FontWeight.w600, color: tokens.onCanvas),
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
          borderSide: BorderSide(color: focusBorder),
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
