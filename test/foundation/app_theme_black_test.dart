import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('black preset uses NativeTavern-like near-black tokens', () {
    final tokens = AppTheme.tokensFor(
      preset: AppThemePreset.black,
      brightness: Brightness.dark,
    );
    expect(tokens.canvas, const Color(0xFF101010));
    expect(tokens.surfaceRaised, const Color(0xFF141414));
    expect(tokens.primary, const Color(0xFF4D9DF4));
    expect(tokens.onCanvas, const Color(0xFFCCCCCC));
    expect(tokens.outlineSubtle, const Color(0xFF2A2A2A));
  });
}
