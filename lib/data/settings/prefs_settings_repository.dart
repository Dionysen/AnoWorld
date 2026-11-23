import 'dart:convert';

import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/domain/settings/ai_preset_state.dart';
import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/domain/settings/persona_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/domain/settings/vn_ui_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository({this.preferences});

  static const aiKey = 'anoworld.ai_settings.v1';
  static const appearanceKey = 'anoworld.appearance.v1';
  static const personasKey = 'anoworld.personas.v1';
  static const aiPresetsKey = 'anoworld.ai_presets.v1';
  static const chatUiKey = 'anoworld.chat_ui.v1';
  static const vnUiKey = 'anoworld.vn_ui.v1';
  static const plotElementsKey = 'anoworld.plot_elements.v1';

  SharedPreferences? preferences;

  Future<SharedPreferences> _prefs() async {
    return preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<AiSettings> loadAi() async {
    final raw = (await _prefs()).getString(aiKey);
    if (raw == null || raw.isEmpty) return const AiSettings();
    final map = asJsonMap(jsonDecode(raw), path: aiKey);
    return AiSettings.fromJson(map);
  }

  @override
  Future<void> saveAi(AiSettings settings) async {
    await (await _prefs()).setString(aiKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<AppearanceSettings> loadAppearance() async {
    final raw = (await _prefs()).getString(appearanceKey);
    if (raw == null || raw.isEmpty) return AppearanceSettings();
    final map = asJsonMap(jsonDecode(raw), path: appearanceKey);
    return AppearanceSettings.fromJson(map);
  }

  @override
  Future<void> saveAppearance(AppearanceSettings settings) async {
    await (await _prefs())
        .setString(appearanceKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<PersonaSettings> loadPersonas() async {
    final raw = (await _prefs()).getString(personasKey);
    if (raw == null || raw.isEmpty) {
      return const PersonaSettings().ensureDefault();
    }
    final map = asJsonMap(jsonDecode(raw), path: personasKey);
    return PersonaSettings.fromJson(map);
  }

  @override
  Future<void> savePersonas(PersonaSettings settings) async {
    await (await _prefs()).setString(
      personasKey,
      jsonEncode(settings.toJson()),
    );
  }

  @override
  Future<AiPresetCatalog> loadAiPresets() async {
    final raw = (await _prefs()).getString(aiPresetsKey);
    if (raw == null || raw.isEmpty) return AiPresetCatalog();
    final map = asJsonMap(jsonDecode(raw), path: aiPresetsKey);
    return AiPresetCatalog.fromJson(map);
  }

  @override
  Future<void> saveAiPresets(AiPresetCatalog catalog) async {
    await (await _prefs()).setString(
      aiPresetsKey,
      jsonEncode(catalog.toJson()),
    );
  }

  @override
  Future<ChatUiSettings> loadChatUi() async {
    final raw = (await _prefs()).getString(chatUiKey);
    if (raw == null || raw.isEmpty) return const ChatUiSettings();
    final map = asJsonMap(jsonDecode(raw), path: chatUiKey);
    return ChatUiSettings.fromJson(map);
  }

  @override
  Future<void> saveChatUi(ChatUiSettings settings) async {
    await (await _prefs()).setString(chatUiKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<VnUiSettings> loadVnUi() async {
    final raw = (await _prefs()).getString(vnUiKey);
    if (raw == null || raw.isEmpty) return const VnUiSettings();
    final map = asJsonMap(jsonDecode(raw), path: vnUiKey);
    return VnUiSettings.fromJson(map);
  }

  @override
  Future<void> saveVnUi(VnUiSettings settings) async {
    await (await _prefs()).setString(vnUiKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<PlotElementCatalog> loadPlotElements() async {
    final raw = (await _prefs()).getString(plotElementsKey);
    if (raw == null || raw.isEmpty) return PlotElementCatalog();
    final map = asJsonMap(jsonDecode(raw), path: plotElementsKey);
    return PlotElementCatalog.fromJson(map);
  }

  @override
  Future<void> savePlotElements(PlotElementCatalog catalog) async {
    await (await _prefs()).setString(
      plotElementsKey,
      jsonEncode(catalog.toJson()),
    );
  }
}
