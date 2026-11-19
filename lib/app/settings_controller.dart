import 'dart:math' as math;

import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/domain/settings/ai_preset_state.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/plot_element_category.dart';
import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/domain/settings/persona_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/fonts/file_system_font_repository.dart';
import 'package:anoworld/foundation/fonts/system_font.dart';
import 'package:anoworld/foundation/theme/theme_color_pack.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Loads and persists AI + appearance settings; notifies [MaterialApp].
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.repository,
    FileSystemFontRepository? fonts,
    Brightness? platformBrightness,
  }) : _fonts = fonts ?? FileSystemFontRepository(),
       platformBrightness =
           platformBrightness ??
           SchedulerBinding.instance.platformDispatcher.platformBrightness;

  final SettingsRepository repository;
  final FileSystemFontRepository _fonts;

  AiSettings ai = const AiSettings();
  AppearanceSettings appearance = AppearanceSettings();
  PersonaSettings personas = const PersonaSettings().ensureDefault();
  AiPresetCatalog aiPresets = AiPresetCatalog();
  ChatUiSettings chatUi = const ChatUiSettings();
  PlotElementCatalog plotElements = PlotElementCatalog();
  Brightness platformBrightness;
  List<SystemFont> fontCatalog = const [];
  bool fontsLoading = false;
  bool fontsLoaded = false;
  bool loaded = false;
  var _nextCustomSeq = 1;

  bool get isEffectivelyDark =>
      appearance.isEffectivelyDark(platformBrightness);

  ThemeTokens get activeTokens => appearance.activeTokens(platformBrightness);

  String get activePackId => appearance.activePackId(platformBrightness);

  ThemeColorPack? get activePack => appearance.packById(activePackId);

  bool get isActivePackCustomized {
    final pack = activePack;
    return pack == null || pack.tokens != activeTokens;
  }

  Future<void> load() async {
    ai = await repository.loadAi();
    appearance = await repository.loadAppearance();
    personas = (await repository.loadPersonas()).ensureDefault();
    aiPresets = await repository.loadAiPresets();
    chatUi = await repository.loadChatUi();
    plotElements = await repository.loadPlotElements();
    if (aiPresets.activePresetId == null) {
      await applyAiPreset(BuiltInAIPresets.defaultPreset);
    }
    _nextCustomSeq = _deriveNextCustomSeq(appearance.customPacks);
    loaded = true;
    notifyListeners();
    await _restoreSavedFont();
  }

  Future<void> updateChatUi(ChatUiSettings next) async {
    chatUi = next;
    notifyListeners();
    await repository.saveChatUi(next);
  }

  Future<void> updatePlotElements(PlotElementCatalog next) async {
    plotElements = next;
    notifyListeners();
    await repository.savePlotElements(next);
  }

  Future<void> upsertPlotElement(PlotElement element) async {
    final next = plotElements.upsertCustom(element);
    await updatePlotElements(next);
    AppLog.instance.info('保存剧情元素：${element.id}', tag: 'plot.elements');
  }

  Future<void> updateBuiltInPlotElement({
    required String id,
    required String keyword,
    required String description,
    String? categoryId,
  }) async {
    final next = plotElements.updateBuiltIn(
      id: id,
      keyword: keyword,
      description: description,
      categoryId: categoryId,
    );
    await updatePlotElements(next);
    AppLog.instance.info('更新默认剧情元素：$id', tag: 'plot.elements');
  }

  Future<PlotElement> addCustomPlotElement({
    required String keyword,
    required String description,
    String categoryId = '',
  }) async {
    final element = PlotElement(
      id: newEntityId('pe'),
      keyword: keyword.trim(),
      description: PlotElementCatalog.clipDescription(description),
      categoryId: categoryId,
    );
    await upsertPlotElement(element);
    return element;
  }

  Future<void> assignPlotElementCategory({
    required String elementId,
    required String categoryId,
  }) async {
    final next = plotElements.assignCategory(elementId, categoryId);
    if (identical(next, plotElements)) return;
    await updatePlotElements(next);
    AppLog.instance.info(
      '剧情元素分类：$elementId → ${categoryId.isEmpty ? '未分类' : categoryId}',
      tag: 'plot.elements',
    );
  }

  Future<PlotElementCategory> addPlotElementCategory(String name) async {
    final category = PlotElementCategory(
      id: newEntityId('pe_cat'),
      name: name.trim(),
    );
    final next = plotElements.addCategory(category);
    if (identical(next, plotElements)) return category;
    await updatePlotElements(next);
    AppLog.instance.info('新建剧情元素分类：${category.name}', tag: 'plot.elements');
    return category;
  }

  Future<void> renamePlotElementCategory(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final next = plotElements.renameCategory(id, trimmed);
    if (identical(next, plotElements)) return;
    await updatePlotElements(next);
    AppLog.instance.info('重命名剧情元素分类：$id → $trimmed', tag: 'plot.elements');
  }

  Future<PlotElementPack> addPlotElementPack(String name) async {
    final pack = PlotElementPack(
      id: newEntityId('pe_pack'),
      name: name.trim(),
    );
    await savePlotElementPack(pack);
    return pack;
  }

  Future<void> savePlotElementPack(PlotElementPack pack) async {
    final next = plotElements.upsertPack(pack);
    if (identical(next, plotElements)) return;
    await updatePlotElements(next);
    AppLog.instance.info(
      '保存剧情元素包：${pack.name}（${pack.count} 条）',
      tag: 'plot.elements',
    );
  }

  Future<void> renamePlotElementPack(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final next = plotElements.renamePack(id, trimmed);
    if (identical(next, plotElements)) return;
    await updatePlotElements(next);
    AppLog.instance.info('重命名剧情元素包：$id → $trimmed', tag: 'plot.elements');
  }

  Future<void> deletePlotElementPack(String id) async {
    final next = plotElements.deletePack(id);
    if (identical(next, plotElements)) return;
    await updatePlotElements(next);
    AppLog.instance.info('删除剧情元素包：$id', tag: 'plot.elements');
  }

  Future<void> deletePlotElement(String id) async {
    final next = plotElements.delete(id);
    await updatePlotElements(next);
    AppLog.instance.info('删除剧情元素：$id', tag: 'plot.elements');
  }

  Future<void> restoreBuiltInPlotElement(String id) async {
    final next = plotElements.restoreBuiltIn(id);
    await updatePlotElements(next);
    AppLog.instance.info('恢复默认剧情元素：$id', tag: 'plot.elements');
  }

  Future<void> restoreAllBuiltInPlotElements() async {
    final next = plotElements.restoreAllBuiltIns();
    await updatePlotElements(next);
    AppLog.instance.info('全部恢复默认剧情元素', tag: 'plot.elements');
  }

  Future<void> updateAi(AiSettings next) async {
    ai = next;
    notifyListeners();
    await repository.saveAi(next);
  }

  Future<void> updateAiPresets(AiPresetCatalog next) async {
    aiPresets = next;
    notifyListeners();
    await repository.saveAiPresets(aiPresets);
  }

  Future<void> updatePromptManager(PromptManagerConfig config) async {
    await updateAiPresets(aiPresets.copyWith(promptManager: config));
  }

  Future<void> updateGeneration(GenerationPreset generation) async {
    await updateAi(ai.copyWith(generation: generation));
  }

  Future<void> applyAiPreset(AIPreset preset) async {
    final gen = preset.generationSettings;
    await updateAi(ai.copyWith(generation: gen));
    final prompt =
        preset.promptManagerConfig ?? PromptManagerConfig.defaultConfig();
    await updateAiPresets(
      aiPresets.copyWith(activePresetId: preset.id, promptManager: prompt),
    );
  }

  Future<AIPreset> importAiPreset(Map<String, dynamic> json) async {
    final id = 'preset_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final preset = AIPreset.fromExportJson(json, id);
    await updateAiPresets(
      aiPresets.copyWith(customPresets: [...aiPresets.customPresets, preset]),
    );
    await applyAiPreset(preset);
    return preset;
  }

  AiPromptContext textPromptContext() {
    return AiPromptContext(
      endpoint: ai.text,
      generation: ai.generation,
      promptManager: aiPresets.promptManager,
      persona: activePersona,
    );
  }

  /// Creates a fresh preset from the default sampling + prompt setup.
  Future<AIPreset> createAiPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name');
    }
    final stamp = DateTime.now().toUtc();
    final preset = AIPreset(
      id: 'preset_${stamp.microsecondsSinceEpoch}',
      name: trimmed,
      createdAt: stamp,
      updatedAt: stamp,
      generationSettings: const GenerationPreset(),
      promptManagerConfig: PromptManagerConfig.defaultConfig(),
    );
    await updateAiPresets(
      aiPresets.copyWith(customPresets: [...aiPresets.customPresets, preset]),
    );
    await applyAiPreset(preset);
    AppLog.instance.info('新建预设：$trimmed', tag: 'ai.preset');
    return preset;
  }

  Future<AIPreset> saveCurrentAsAiPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name');
    }
    final stamp = DateTime.now().toUtc();
    final preset = AIPreset(
      id: 'preset_${stamp.microsecondsSinceEpoch}',
      name: trimmed,
      createdAt: stamp,
      updatedAt: stamp,
      generationSettings: ai.generation,
      promptManagerConfig: aiPresets.promptManager,
    );
    await updateAiPresets(
      aiPresets.copyWith(customPresets: [...aiPresets.customPresets, preset]),
    );
    await applyAiPreset(preset);
    AppLog.instance.info('保存当前设置为预设：$trimmed', tag: 'ai.preset');
    return preset;
  }

  Future<AIPreset> copyAiPresetToCustom(
    AIPreset template, {
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name');
    }
    final stamp = DateTime.now().toUtc();
    final copy = template.copyWith(
      id: 'preset_${stamp.microsecondsSinceEpoch}',
      name: trimmed,
      isBuiltIn: false,
      createdAt: stamp,
      updatedAt: stamp,
      generationSettings: template.generationSettings,
      promptManagerConfig:
          template.promptManagerConfig ?? aiPresets.promptManager,
    );
    await updateAiPresets(
      aiPresets.copyWith(customPresets: [...aiPresets.customPresets, copy]),
    );
    return copy;
  }

  Future<void> renameCustomAiPreset(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final next = aiPresets.customPresets
        .map((p) {
          if (p.id != id) return p;
          return p.copyWith(name: trimmed, updatedAt: DateTime.now().toUtc());
        })
        .toList(growable: false);
    await updateAiPresets(aiPresets.copyWith(customPresets: next));
    AppLog.instance.info('重命名预设：$trimmed', tag: 'ai.preset');
  }

  Future<void> deleteCustomAiPreset(String id) async {
    final next = aiPresets.customPresets
        .where((p) => p.id != id)
        .toList(growable: false);
    final clearActive = aiPresets.activePresetId == id;
    await updateAiPresets(
      aiPresets.copyWith(customPresets: next, clearActive: clearActive),
    );
    AppLog.instance.info('删除预设：$id', tag: 'ai.preset');
  }

  UserPersona? get activePersona => personas.activePersona;

  Future<void> updatePersonas(PersonaSettings next) async {
    personas = next.ensureDefault();
    notifyListeners();
    await repository.savePersonas(personas);
  }

  Future<void> setActivePersona(String id) async {
    if (!personas.personas.any((p) => p.id == id)) return;
    AppLog.instance.info('切换当前身份：$id', tag: 'persona');
    await updatePersonas(personas.copyWith(activePersonaId: id));
  }

  Future<UserPersona> createPersona({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name');
    }
    final stamp = DateTime.now().toUtc();
    final persona = UserPersona(
      id: 'persona_${stamp.microsecondsSinceEpoch}',
      name: trimmed,
      createdAt: stamp,
      updatedAt: stamp,
    );
    final next = personas.withPersonas([...personas.personas, persona]);
    await updatePersonas(next.copyWith(activePersonaId: persona.id));
    AppLog.instance.info('添加身份：${persona.id}', tag: 'persona');
    return persona;
  }

  Future<void> savePersona(UserPersona persona) async {
    final list = personas.personas
        .map((p) {
          return p.id == persona.id
              ? persona.copyWith(updatedAt: DateTime.now().toUtc())
              : p;
        })
        .toList(growable: false);
    await updatePersonas(personas.copyWith(personas: list));
    AppLog.instance.info('保存身份：${persona.id}', tag: 'persona');
  }

  Future<void> deletePersona(String id) async {
    final target = personas.personas.where((p) => p.id == id).firstOrNull;
    if (target == null || target.isDefault) {
      AppLog.instance.warning('无法删除身份：$id', tag: 'persona');
      return;
    }
    final list = personas.personas
        .where((p) => p.id != id)
        .toList(growable: false);
    await updatePersonas(personas.withPersonas(list));
    AppLog.instance.info('删除身份：$id', tag: 'persona');
  }

  Future<void> setDefaultPersona(String id) async {
    final list = personas.personas
        .map((p) => p.copyWith(isDefault: p.id == id))
        .toList(growable: false);
    await updatePersonas(personas.copyWith(personas: list));
  }

  Future<void> updateAppearance(AppearanceSettings next) async {
    appearance = next;
    notifyListeners();
    await repository.saveAppearance(next);
  }

  void syncPlatformBrightness(Brightness brightness) {
    if (platformBrightness == brightness) return;
    platformBrightness = brightness;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeModeSetting mode) async {
    if (appearance.mode == mode) return;
    await updateAppearance(appearance.copyWith(mode: mode));
  }

  Future<void> applyPack(String packId) async {
    final pack = appearance.packById(packId);
    if (pack == null) return;
    if (isEffectivelyDark) {
      await updateAppearance(
        appearance.copyWith(darkTokens: pack.tokens, darkPackId: pack.id),
      );
    } else {
      await updateAppearance(
        appearance.copyWith(lightTokens: pack.tokens, lightPackId: pack.id),
      );
    }
  }

  Future<void> updateToken(ThemeToken token, int value) async {
    if (isEffectivelyDark) {
      await updateAppearance(
        appearance.copyWith(
          darkTokens: appearance.darkTokens.withValue(token, value),
        ),
      );
    } else {
      await updateAppearance(
        appearance.copyWith(
          lightTokens: appearance.lightTokens.withValue(token, value),
        ),
      );
    }
  }

  Future<void> restoreDefaults() async {
    final pack = activePack;
    if (pack == null) return;
    await applyPack(pack.id);
  }

  int nextDefaultThemeNumber() {
    final pattern = RegExp(r'^(?:主题|Theme)\s*(\d+)$', caseSensitive: false);
    var max = 0;
    for (final pack in appearance.customPacks) {
      final match = pattern.firstMatch(pack.name.trim());
      if (match != null) {
        max = math.max(max, int.parse(match.group(1)!));
      }
    }
    return max + 1;
  }

  Future<void> saveCurrentAsTheme(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final pack = _createCustomPack(name: trimmed, tokens: activeTokens);
    final packs = [...appearance.customPacks, pack];
    var next = appearance.copyWith(customPacks: packs);
    next = isEffectivelyDark
        ? next.copyWith(darkPackId: pack.id)
        : next.copyWith(lightPackId: pack.id);
    await updateAppearance(next);
  }

  Future<void> renameCustomPack(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = appearance.customPacks.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final packs = List<ThemeColorPack>.of(appearance.customPacks);
    packs[index] = packs[index].copyWith(name: trimmed);
    await updateAppearance(appearance.copyWith(customPacks: packs));
  }

  Future<void> copyCustomPack(String id, String name) async {
    final source = appearance.customPacks.where((p) => p.id == id).firstOrNull;
    final trimmed = name.trim();
    if (source == null || trimmed.isEmpty) return;
    final pack = _createCustomPack(name: trimmed, tokens: source.tokens);
    await updateAppearance(
      appearance.copyWith(customPacks: [...appearance.customPacks, pack]),
    );
  }

  Future<void> deleteCustomPack(String id) async {
    if (!appearance.customPacks.any((p) => p.id == id)) return;
    var next = appearance.copyWith(
      customPacks: [
        for (final pack in appearance.customPacks)
          if (pack.id != id) pack,
      ],
    );
    if (next.lightPackId == id) {
      next = next.copyWith(
        lightPackId: ThemeColorPack.builtInId(ThemePreset.light),
        lightTokens: ThemeTokens.presets[ThemePreset.light]!,
      );
    }
    if (next.darkPackId == id) {
      next = next.copyWith(
        darkPackId: ThemeColorPack.builtInId(ThemePreset.darkModern),
        darkTokens: ThemeTokens.defaults,
      );
    }
    await updateAppearance(next);
  }

  Future<void> ensureFontsLoaded({bool force = false}) async {
    if (fontsLoading) return;
    if (fontsLoaded && !force) return;
    fontsLoading = true;
    notifyListeners();
    try {
      fontCatalog = await _fonts.listFonts();
      fontsLoaded = true;
    } on Object {
      fontsLoaded = true;
    } finally {
      fontsLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectFont(SystemFont? font) async {
    if (font == null) {
      await updateAppearance(appearance.copyWith(clearFont: true));
      return;
    }
    final family = await _fonts.loadFont(font);
    if (family == null) return;
    await updateAppearance(
      appearance.copyWith(fontFamily: family, fontPath: font.path),
    );
  }

  Future<bool> importFontFromPath(String sourcePath) async {
    final imported = await _fonts.importFont(sourcePath);
    if (imported == null) return false;
    try {
      fontCatalog = await _fonts.listFonts();
      fontsLoaded = true;
    } on Object {
      if (!fontCatalog.any((f) => f.path == imported.path)) {
        fontCatalog = [...fontCatalog, imported];
        fontsLoaded = true;
      }
    }
    notifyListeners();
    await selectFont(imported);
    return appearance.fontPath == imported.path;
  }

  Future<bool> deleteImportedFont(SystemFont font) async {
    final ok = await _fonts.deleteImportedFont(font);
    if (!ok) return false;
    try {
      fontCatalog = await _fonts.listFonts();
      fontsLoaded = true;
    } on Object {
      fontCatalog = fontCatalog.where((f) => f.path != font.path).toList();
    }
    if (appearance.fontPath == font.path) {
      await selectFont(null);
    } else {
      notifyListeners();
    }
    return true;
  }

  String selectedFontLabel({String systemLabel = '系统默认'}) {
    final path = appearance.fontPath;
    if (path == null || path.isEmpty) {
      final family = appearance.fontFamily;
      if (family != null && family.isNotEmpty) return family;
      return systemLabel;
    }
    for (final font in fontCatalog) {
      if (font.path == path) return font.family;
    }
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  ThemeColorPack _createCustomPack({
    required String name,
    required ThemeTokens tokens,
  }) {
    final id = 'custom_$_nextCustomSeq';
    _nextCustomSeq += 1;
    return ThemeColorPack(id: id, name: name, tokens: tokens);
  }

  int _deriveNextCustomSeq(List<ThemeColorPack> packs) {
    var max = 0;
    for (final pack in packs) {
      final match = RegExp(r'^custom_(\d+)$').firstMatch(pack.id);
      if (match != null) {
        max = math.max(max, int.parse(match.group(1)!));
      }
    }
    return max + 1;
  }

  Future<void> _restoreSavedFont() async {
    final path = appearance.fontPath;
    if (path == null || path.isEmpty) return;
    if (await _fonts.fontFileMissing(path)) {
      await updateAppearance(appearance.copyWith(clearFont: true));
      return;
    }
    final family = await _fonts.loadFont(SystemFont(family: '', path: path));
    if (family != null) {
      await updateAppearance(appearance.copyWith(fontFamily: family));
    }
  }
}
