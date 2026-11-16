import 'package:anoworld/data/settings/prefs_settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prefs settings repository round-trips ai and appearance', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsSettingsRepository(preferences: prefs);

    await repo.saveAi(
      const AiSettings(
        text: AiEndpointConfig(
          kind: AiProviderKind.deepSeek,
          baseUrl: 'https://api.deepseek.com/v1',
          apiKey: 'sk-test',
          model: 'gpt-test',
        ),
      ),
    );
    await repo.saveAppearance(
      const AppearanceSettings(
        mode: AppThemeModeSetting.light,
        preset: AppThemePreset.mist,
        typeface: AppTypeface.sans,
        fontSize: 16.5,
        cornerRadius: 16,
      ),
    );

    final ai = await repo.loadAi();
    expect(ai.text.model, 'gpt-test');
    expect(ai.text.apiKey, 'sk-test');
    expect(ai.text.kind, AiProviderKind.deepSeek);

    final appearance = await repo.loadAppearance();
    expect(appearance.mode, AppThemeModeSetting.light);
    expect(appearance.preset, AppThemePreset.mist);
    expect(appearance.typeface, AppTypeface.sans);
    expect(appearance.fontSize, 16.5);
    expect(appearance.cornerRadius, 16);
  });
}
