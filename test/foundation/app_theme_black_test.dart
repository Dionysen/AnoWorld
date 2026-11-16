import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cursorDark preset uses NativeTavern near-black tokens', () {
    final tokens = AppTheme.tokensFor(
      ThemeTokens.presets[ThemePreset.cursorDark]!,
    );
    expect(tokens.canvas, const Color(0xFF141414));
    expect(tokens.surfaceRaised, const Color(0xFF232323));
    expect(tokens.primary, const Color(0xFF4D9DF4));
    expect(tokens.secondary, const Color(0xFF6CB6FF));
    expect(tokens.tertiary, const Color(0xFFD4B483));
    expect(tokens.onCanvas, const Color(0xFFCCCCCC));
    expect(tokens.outlineSubtle, const Color(0xFF2A2A2A));
  });

  test('ColorScheme maps accent / secondary / tertiary from ThemeTokens', () {
    final themeTokens = ThemeTokens.presets[ThemePreset.graphite]!;
    final colors = AppTheme.tokensFor(themeTokens);
    final scheme = AppTheme.colorSchemeFor(
      colors,
      brightness: Brightness.dark,
    );

    expect(scheme.primary, Color(themeTokens.accent));
    expect(scheme.secondary, Color(themeTokens.secondaryAccent));
    expect(scheme.tertiary, Color(themeTokens.tertiaryAccent));
    expect(scheme.onPrimary, Colors.white);
    expect(scheme.onSecondary, Colors.white);
    expect(scheme.onTertiary, Colors.white);
    expect(scheme.surface, colors.canvas);
    expect(scheme.surfaceContainerLowest, colors.sidebar);
  });

  test('ThemeData wires accent into selection and switch track', () {
    final appearance = AppearanceSettings(
      darkTokens: ThemeTokens.presets[ThemePreset.espresso]!,
    );
    final theme = AppTheme.dark(appearance);
    final accent = Color(appearance.darkTokens.accent);

    expect(theme.colorScheme.primary, accent);
    expect(theme.colorScheme.secondary,
        Color(appearance.darkTokens.secondaryAccent));
    expect(theme.colorScheme.tertiary,
        Color(appearance.darkTokens.tertiaryAccent));
    expect(theme.textSelectionTheme.cursorColor,
        Color(appearance.darkTokens.cursor));
    expect(
      theme.switchTheme.trackColor!
          .resolve({WidgetState.selected}),
      accent,
    );
  });
}
