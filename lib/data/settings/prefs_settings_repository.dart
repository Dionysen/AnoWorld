import 'dart:convert';

import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository({this.preferences});

  static const aiKey = 'anoworld.ai_settings.v1';
  static const appearanceKey = 'anoworld.appearance.v1';

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
    if (raw == null || raw.isEmpty) return const AppearanceSettings();
    final map = asJsonMap(jsonDecode(raw), path: appearanceKey);
    return AppearanceSettings.fromJson(map);
  }

  @override
  Future<void> saveAppearance(AppearanceSettings settings) async {
    await (await _prefs())
        .setString(appearanceKey, jsonEncode(settings.toJson()));
  }
}
