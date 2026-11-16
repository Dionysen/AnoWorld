import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';

class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository({
    AiSettings? ai,
    AppearanceSettings? appearance,
  })  : _ai = ai ?? const AiSettings(),
        _appearance = appearance ?? const AppearanceSettings();

  AiSettings _ai;
  AppearanceSettings _appearance;

  @override
  Future<AiSettings> loadAi() async => _ai;

  @override
  Future<void> saveAi(AiSettings settings) async {
    _ai = settings;
  }

  @override
  Future<AppearanceSettings> loadAppearance() async => _appearance;

  @override
  Future<void> saveAppearance(AppearanceSettings settings) async {
    _appearance = settings;
  }
}
