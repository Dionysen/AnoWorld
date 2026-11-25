import 'dart:convert';

import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/plot_element_category.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled seed data under `assets/seed/` (plot elements, AI presets, default prompts).
///
/// Call [load] once before [runApp] / test widgets that touch built-ins.
class SeedCatalog {
  SeedCatalog._();

  static const plotElementsAsset = 'assets/seed/plot_elements.json';
  static const aiPresetsAsset = 'assets/seed/ai_presets.json';
  static const promptDefaultAsset = 'assets/seed/prompt_default.json';

  static bool _loaded = false;
  static List<PlotElementCategory> _categories = const [];
  static List<PlotElement> _elements = const [];
  static Map<String, PlotElementCategory> _categoriesById = const {};
  static Map<String, PlotElement> _elementsById = const {};
  static List<AIPreset> _presets = const [];
  static Map<String, AIPreset> _presetsById = const {};
  static PromptManagerConfig _promptDefault =
      PromptManagerConfig.defaultConfig();

  static bool get isLoaded => _loaded;

  static List<PlotElementCategory> get categories => _categories;
  static List<PlotElement> get elements => _elements;
  static Map<String, PlotElementCategory> get categoriesById => _categoriesById;
  static Map<String, PlotElement> get elementsById => _elementsById;

  static List<AIPreset> get presets => _presets;
  static Map<String, AIPreset> get presetsById => _presetsById;

  static AIPreset get defaultPreset {
    final fromSeed = _presetsById['default'];
    if (fromSeed != null) return fromSeed;
    if (_presets.isNotEmpty) return _presets.first;
    return _minimalDefaultPreset();
  }

  static PromptManagerConfig get promptDefault => _promptDefault;

  /// Load seed JSON from the asset bundle (or [assetBundle] in tests).
  static Future<void> load({AssetBundle? assetBundle}) async {
    final bundle = assetBundle ?? rootBundle;
    try {
      final plotRaw = await bundle.loadString(plotElementsAsset);
      final presetsRaw = await bundle.loadString(aiPresetsAsset);
      final promptRaw = await bundle.loadString(promptDefaultAsset);
      applyParsed(
        plotJson: jsonDecode(plotRaw),
        presetsJson: jsonDecode(presetsRaw),
        promptJson: jsonDecode(promptRaw),
      );
    } catch (error, stack) {
      AppLog.instance.error(
        '加载内置种子失败',
        tag: 'seed',
        error: error,
        stackTrace: stack,
      );
      if (kDebugMode) {
        Error.throwWithStackTrace(error, stack);
      }
      _applyFallback();
    }
  }

  /// Parse already-decoded JSON (unit tests / tooling).
  static void applyParsed({
    required Object? plotJson,
    required Object? presetsJson,
    required Object? promptJson,
  }) {
    final plot = asJsonMap(plotJson, path: 'plot_elements');
    final categories = plot
        .optionalList('categories')
        .map(
          (item) => PlotElementCategory.fromJson(
            asJsonMap(item, path: 'categories[]'),
          ),
        )
        .toList(growable: false);
    final elements = plot
        .optionalList('elements')
        .map(
          (item) => PlotElement.fromJson(asJsonMap(item, path: 'elements[]')),
        )
        .toList(growable: false);
    if (categories.isEmpty) {
      throw const FormatException('plot_elements.json: categories is empty');
    }
    if (elements.isEmpty) {
      throw const FormatException('plot_elements.json: elements is empty');
    }

    final presetsRoot = asJsonMap(presetsJson, path: 'ai_presets');
    final presets = presetsRoot
        .optionalList('presets')
        .map((item) {
          final map = asJsonMap(item, path: 'presets[]');
          final preset = AIPreset.fromJson(map);
          return preset.isBuiltIn ? preset : preset.copyWith(isBuiltIn: true);
        })
        .toList(growable: false);
    if (presets.isEmpty) {
      throw const FormatException('ai_presets.json: presets is empty');
    }

    final promptRoot = asJsonMap(promptJson, path: 'prompt_default');
    final sectionsRaw = promptRoot['sections'];
    if (sectionsRaw is! List || sectionsRaw.isEmpty) {
      throw const FormatException('prompt_default.json: sections is empty');
    }
    final prompt = PromptManagerConfig.fromJson(promptRoot);

    _categories = categories;
    _elements = elements;
    _categoriesById = {for (final c in categories) c.id: c};
    _elementsById = {for (final e in elements) e.id: e};
    _presets = presets;
    _presetsById = {for (final p in presets) p.id: p};
    _promptDefault = prompt;
    PromptManagerConfig.bindSeedDefault(prompt);
    _loaded = true;
    AppLog.instance.info(
      '内置种子已加载：情节 ${elements.length}，预设 ${presets.length}',
      tag: 'seed',
    );
  }

  /// Test helper: clear so the next [load] runs again.
  @visibleForTesting
  static void resetForTest() {
    PromptManagerConfig.clearSeedDefaultForTest();
    _loaded = false;
    _categories = const [];
    _elements = const [];
    _categoriesById = const {};
    _elementsById = const {};
    _presets = const [];
    _presetsById = const {};
    _promptDefault = PromptManagerConfig.defaultConfig();
  }

  static void _applyFallback() {
    PromptManagerConfig.clearSeedDefaultForTest();
    _categories = const [];
    _elements = const [];
    _categoriesById = const {};
    _elementsById = const {};
    final preset = _minimalDefaultPreset();
    _presets = [preset];
    _presetsById = {preset.id: preset};
    final prompt = PromptManagerConfig.defaultConfig();
    _promptDefault = prompt;
    PromptManagerConfig.bindSeedDefault(prompt);
    _loaded = true;
  }

  static AIPreset _minimalDefaultPreset() {
    return AIPreset(
      id: 'default',
      name: 'Default',
      description: 'Fallback built-in preset',
      isBuiltIn: true,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
      generationSettings: const GenerationPreset(),
    );
  }
}
