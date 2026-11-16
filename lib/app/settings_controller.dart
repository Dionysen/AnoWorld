import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:flutter/foundation.dart';

/// Loads and persists AI + appearance settings; notifies [MaterialApp].
class SettingsController extends ChangeNotifier {
  SettingsController({required this.repository});

  final SettingsRepository repository;

  AiSettings ai = const AiSettings();
  AppearanceSettings appearance = const AppearanceSettings();
  bool loaded = false;

  Future<void> load() async {
    ai = await repository.loadAi();
    appearance = await repository.loadAppearance();
    loaded = true;
    notifyListeners();
  }

  Future<void> updateAi(AiSettings next) async {
    ai = next;
    notifyListeners();
    await repository.saveAi(next);
  }

  Future<void> updateAppearance(AppearanceSettings next) async {
    appearance = next;
    notifyListeners();
    await repository.saveAppearance(next);
  }
}
