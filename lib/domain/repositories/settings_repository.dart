import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';

abstract interface class SettingsRepository {
  Future<AiSettings> loadAi();

  Future<void> saveAi(AiSettings settings);

  Future<AppearanceSettings> loadAppearance();

  Future<void> saveAppearance(AppearanceSettings settings);
}
