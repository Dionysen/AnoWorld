import 'package:anoworld/data/settings/prefs_settings_repository.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/domain/settings/built_in_plot_elements.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/domain/settings/vn_ui_settings.dart';
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
      AppearanceSettings(
        mode: AppThemeModeSetting.light,
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

  test('prefs settings repository round-trips plot element catalog', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsSettingsRepository(preferences: prefs);
    final seedId = BuiltInPlotElements.all.first.id;

    await repo.savePlotElements(
      PlotElementCatalog()
          .updateBuiltIn(
            id: seedId,
            keyword: '覆写词',
            description: '覆写描述',
          )
          .upsertCustom(
            const PlotElement(
              id: 'pe_user',
              keyword: '自建',
              description: '说明',
            ),
          ),
    );

    final loaded = await repo.loadPlotElements();
    expect(loaded.overrides[seedId]?.keyword, '覆写词');
    expect(loaded.custom.single.id, 'pe_user');
  });

  test('prefs settings repository round-trips VN display prefs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsSettingsRepository(preferences: prefs);

    await repo.saveVnUi(
      const VnUiSettings(
        lines: 6,
        fontSize: 19,
        backgroundHex: '#10131B',
        textHex: '#F0F0F0',
        opacity: 0.6,
      ),
    );

    final loaded = await repo.loadVnUi();
    expect(loaded.lines, 6);
    expect(loaded.fontSize, 19);
    expect(loaded.backgroundHex, '#10131B');
    expect(loaded.textHex, '#F0F0F0');
    expect(loaded.opacity, 0.6);
  });
}
