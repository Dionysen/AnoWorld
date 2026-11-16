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
        text: AiTextEndpoint(
          kind: AiTextProviderKind.deepSeek,
          baseUrl: 'https://api.deepseek.com/v1',
          apiKey: 'sk-test',
          model: 'gpt-test',
        ),
        image: AiImageEndpoint(
          kind: AiImageProviderKind.comfyui,
          baseUrl: 'http://127.0.0.1:8188',
          model: 'sdxl',
        ),
      ),
    );
    await repo.saveAppearance(
      const AppearanceSettings(
        mode: AppThemeModeSetting.light,
        preset: AppThemePreset.mist,
        fontFamily: 'Roboto',
        fontSize: 16.5,
        cornerRadius: 16,
      ),
    );

    final ai = await repo.loadAi();
    expect(ai.text.model, 'gpt-test');
    expect(ai.text.kind, AiTextProviderKind.deepSeek);
    expect(ai.image.kind, AiImageProviderKind.comfyui);

    final appearance = await repo.loadAppearance();
    expect(appearance.mode, AppThemeModeSetting.light);
    expect(appearance.fontSize, 16.5);
  });
}
