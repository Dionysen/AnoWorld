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
    expect(tokens.onCanvas, const Color(0xFFCCCCCC));
    expect(tokens.outlineSubtle, const Color(0xFF2A2A2A));
  });
}
