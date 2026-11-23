import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/domain/settings/ai_preset_state.dart';
import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/domain/settings/persona_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/domain/settings/vn_ui_settings.dart';

abstract interface class SettingsRepository {
  Future<AiSettings> loadAi();

  Future<void> saveAi(AiSettings settings);

  Future<AppearanceSettings> loadAppearance();

  Future<void> saveAppearance(AppearanceSettings settings);

  Future<PersonaSettings> loadPersonas();

  Future<void> savePersonas(PersonaSettings settings);

  Future<AiPresetCatalog> loadAiPresets();

  Future<void> saveAiPresets(AiPresetCatalog catalog);

  Future<ChatUiSettings> loadChatUi();

  Future<void> saveChatUi(ChatUiSettings settings);

  Future<VnUiSettings> loadVnUi();

  Future<void> saveVnUi(VnUiSettings settings);

  Future<PlotElementCatalog> loadPlotElements();

  Future<void> savePlotElements(PlotElementCatalog catalog);
}
