import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';

/// SillyTavern-style preset catalog (global, persisted).
class AiPresetCatalog {
  AiPresetCatalog({
    this.customPresets = const <AIPreset>[],
    this.activePresetId,
    PromptManagerConfig? promptManager,
  }) : promptManager = promptManager ?? PromptManagerConfig.defaultConfig();

  final List<AIPreset> customPresets;
  final String? activePresetId;

  /// Live prompt order/content (also updated when applying a preset).
  final PromptManagerConfig promptManager;

  List<AIPreset> get allPresets {
    final customIds = customPresets.map((p) => p.id).toSet();
    final builtIn = BuiltInAIPresets.all
        .where((p) => !customIds.contains(p.id))
        .toList(growable: false);
    return [...builtIn, ...customPresets];
  }

  AIPreset? get activePreset {
    final id = activePresetId;
    if (id == null) return null;
    for (final p in allPresets) {
      if (p.id == id) return p;
    }
    return null;
  }

  AiPresetCatalog copyWith({
    List<AIPreset>? customPresets,
    String? activePresetId,
    bool clearActive = false,
    PromptManagerConfig? promptManager,
  }) {
    return AiPresetCatalog(
      customPresets: customPresets ?? this.customPresets,
      activePresetId:
          clearActive ? null : (activePresetId ?? this.activePresetId),
      promptManager: promptManager ?? this.promptManager,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'customPresets': customPresets.map((p) => p.toJson()).toList(),
        if (activePresetId != null) 'activePresetId': activePresetId,
        'promptManager': promptManager.toJson(),
      };

  factory AiPresetCatalog.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AiPresetCatalog();
    final presets = <AIPreset>[
      for (final item in json.optionalList('customPresets'))
        AIPreset.fromJson(asJsonMap(item, path: 'customPresets[]')),
    ];
    final pmRaw = json.optionalMap('promptManager');
    return AiPresetCatalog(
      customPresets: presets,
      activePresetId: json.optionalString('activePresetId'),
      promptManager: pmRaw == null
          ? null
          : PromptManagerConfig.fromJson(pmRaw),
    );
  }
}