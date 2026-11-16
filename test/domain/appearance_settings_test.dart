import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppearanceSettings json round-trip keeps numeric ui prefs', () {
    const original = AppearanceSettings(
      mode: AppThemeModeSetting.system,
      preset: AppThemePreset.slate,
      typeface: AppTypeface.sans,
      fontSize: 16.5,
      cornerRadius: 16,
    );

    final restored = AppearanceSettings.fromJson(original.toJson());
    expect(restored.mode, original.mode);
    expect(restored.preset, original.preset);
    expect(restored.typeface, original.typeface);
    expect(restored.fontSize, original.fontSize);
    expect(restored.cornerRadius, original.cornerRadius);
  });

  test('AppearanceSettings migrates legacy fontScale multiplier', () {
    final restored = AppearanceSettings.fromJson(<String, dynamic>{
      'mode': 'dark',
      'preset': 'midnight',
      'typeface': 'system',
      'fontScale': 1.0,
      'cornerRadius': 'soft',
    });
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
}
