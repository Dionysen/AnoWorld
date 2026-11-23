import 'package:flutter/material.dart';

import 'app_hex_color.dart';
import 'app_theme.dart';

/// Fixed-size frosted dialogue box metrics.
///
/// Height depends only on [lines] and [fontSize] — never on how much text a
/// turn produced — so the stage never jumps while text pages advance.
abstract final class AppDialogueChrome {
  /// Visible body lines per page.
  static const int minLines = 2;
  static const int maxLines = 8;
  static const int defaultLines = 4;

  static const double minFontSize = 13;
  static const double maxFontSize = 26;
  static const double defaultFontSize = 16;
  static const double fontSizeStep = 1;

  /// Body line-height multiplier; the pager measures with the same value.
  static const double lineHeight = 1.5;

  /// Reserved speaker row (kept even for narration so height stays constant).
  static const double headerHeight = 24;

  static const EdgeInsets padding = EdgeInsets.all(AppTheme.spaceMd);

  /// Semi-transparent glass fill; the panel blurs whatever sits behind it.
  static const double defaultOpacity = 0.72;
  static const double minOpacity = 0.2;
  static const double maxOpacity = 1;
  static const double opacityStep = 0.02;

  /// Typewriter speed in characters per second; 0 shows text instantly.
  static const double defaultTextSpeed = 28;
  static const double minTextSpeed = 0;
  static const double maxTextSpeed = 60;
  static const double textSpeedStep = 1;

  /// Gaussian blur applied to the stage behind the panel.
  static const double blurSigma = 14;

  static double bodyHeight(int lines, double fontSize) =>
      lines * fontSize * lineHeight;

  static double panelHeight({required int lines, required double fontSize}) =>
      headerHeight + bodyHeight(lines, fontSize) + padding.vertical;

  /// Text width available inside a panel of [panelWidth].
  static double textWidth(double panelWidth) => panelWidth - padding.horizontal;

  /// Body style for both rendering and pagination.
  ///
  /// [color] overrides the theme body colour (the reading pref); null keeps it.
  static TextStyle bodyStyle(
    BuildContext context,
    double fontSize, {
    bool italic = false,
    Color? color,
  }) {
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: fontSize,
      height: lineHeight,
      fontStyle: italic ? FontStyle.italic : null,
      color: color,
    );
  }

  /// Panel fill: custom [backgroundHex], else the theme surface.
  static Color fill(
    BuildContext context, {
    required String backgroundHex,
    required double opacity,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final base =
        tryParseHexColor(backgroundHex) ?? scheme.surfaceContainerHighest;
    return base.withValues(alpha: opacity.clamp(minOpacity, maxOpacity));
  }
}
