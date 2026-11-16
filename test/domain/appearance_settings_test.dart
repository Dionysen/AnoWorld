import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/theme_color_pack.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppearanceSettings json round-trip keeps dual color slots', () {
    final original = AppearanceSettings(
      mode: AppThemeModeSetting.system,
      lightTokens: ThemeTokens.presets[ThemePreset.mint]!,
      darkTokens: ThemeTokens.presets[ThemePreset.cursorDark]!,
      lightPackId: ThemeColorPack.builtInId(ThemePreset.mint),
      darkPackId: ThemeColorPack.builtInId(ThemePreset.cursorDark),
      fontFamily: 'app-font-1',
      fontPath: r'C:\Fonts\Demo.ttf',
      fontSize: 16.5,
      cornerRadius: 16,
    );

    final restored = AppearanceSettings.fromJson(original.toJson());
    expect(restored.mode, original.mode);
    expect(restored.lightPackId, original.lightPackId);
    expect(restored.darkPackId, original.darkPackId);
    expect(restored.lightTokens, original.lightTokens);
    expect(restored.darkTokens, original.darkTokens);
    expect(restored.fontFamily, original.fontFamily);
    expect(restored.fontPath, original.fontPath);
    expect(restored.fontSize, original.fontSize);
    expect(restored.cornerRadius, original.cornerRadius);
  });

  test('AppearanceSettings migrates legacy single preset', () {
    final restored = AppearanceSettings.fromJson(<String, dynamic>{
      'mode': 'dark',
      'preset': 'black',
      'fontScale': 1.0,
      'cornerRadius': 'soft',
    });
    expect(restored.darkPackId, ThemeColorPack.builtInId(ThemePreset.cursorDark));
    expect(
      restored.darkTokens,
      ThemeTokens.presets[ThemePreset.cursorDark],
    );
    expect(restored.lightPackId, ThemeColorPack.builtInId(ThemePreset.light));
    expect(restored.fontSize, 15);
    expect(restored.cornerRadius, 16);
  });

  test('AppearanceSettings migrates legacy enum strings', () {
    final restored = AppearanceSettings.fromJson(<String, dynamic>{
      'fontScale': 'large',
      'cornerRadius': 'compact',
    });
    expect(restored.fontSize, 17);
    expect(restored.cornerRadius, 6);
  });

  test('clearFont clears family and path', () {
    final original = AppearanceSettings(
      fontFamily: 'x',
      fontPath: '/a.ttf',
    );
    final cleared = original.copyWith(clearFont: true);
    expect(cleared.fontFamily, isNull);
    expect(cleared.fontPath, isNull);
  });
}
