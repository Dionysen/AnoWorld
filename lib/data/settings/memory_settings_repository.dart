import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/domain/settings/ai_preset_state.dart';
import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/domain/settings/persona_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';

class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository({
    AiSettings? ai,
    AppearanceSettings? appearance,
    PersonaSettings? personas,
    AiPresetCatalog? aiPresets,
    ChatUiSettings? chatUi,
    PlotElementCatalog? plotElements,
  })  : _ai = ai ?? const AiSettings(),
        _appearance = appearance ?? AppearanceSettings(),
        _personas = personas ?? const PersonaSettings().ensureDefault(),
        _aiPresets = aiPresets ?? AiPresetCatalog(),
        _chatUi = chatUi ?? const ChatUiSettings(),
        _plotElements = plotElements ?? PlotElementCatalog();

  AiSettings _ai;
  AppearanceSettings _appearance;
  PersonaSettings _personas;
  AiPresetCatalog _aiPresets;
  ChatUiSettings _chatUi;
  PlotElementCatalog _plotElements;

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

  @override
  Future<PersonaSettings> loadPersonas() async => _personas;

  @override
  Future<void> savePersonas(PersonaSettings settings) async {
    _personas = settings;
  }

  @override
  Future<AiPresetCatalog> loadAiPresets() async => _aiPresets;

  @override
  Future<void> saveAiPresets(AiPresetCatalog catalog) async {
    _aiPresets = catalog;
  }

  @override
  Future<ChatUiSettings> loadChatUi() async => _chatUi;

  @override
  Future<void> saveChatUi(ChatUiSettings settings) async {
    _chatUi = settings;
  }

  @override
  Future<PlotElementCatalog> loadPlotElements() async => _plotElements;

  @override
  Future<void> savePlotElements(PlotElementCatalog catalog) async {
    _plotElements = catalog;
  }
}
