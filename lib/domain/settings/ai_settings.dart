import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';

/// Text/LLM providers (OpenAI-compatible HTTP). Inspired by NativeTavern `LLMProvider`.
enum AiTextProviderKind {
  openAiCompatible,
  openai,
  deepSeek,
  openRouter,
  qwen,
  siliconFlow,
  moonshot,
  zai,
  miniMax,
  ollama,
}

extension AiTextProviderKindX on AiTextProviderKind {
  String get defaultBaseUrl => switch (this) {
        AiTextProviderKind.openAiCompatible => 'http://localhost:8080/v1',
        AiTextProviderKind.openai => 'https://api.openai.com/v1',
        AiTextProviderKind.deepSeek => 'https://api.deepseek.com/v1',
        AiTextProviderKind.openRouter => 'https://openrouter.ai/api/v1',
        AiTextProviderKind.qwen =>
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
        AiTextProviderKind.siliconFlow => 'https://api.siliconflow.cn/v1',
        AiTextProviderKind.moonshot => 'https://api.moonshot.cn/v1',
        AiTextProviderKind.zai => 'https://open.bigmodel.cn/api/paas/v4',
        AiTextProviderKind.miniMax => 'https://api.minimaxi.com/v1',
        AiTextProviderKind.ollama => 'http://localhost:11434/v1',
      };

  String get defaultModel => switch (this) {
        AiTextProviderKind.openAiCompatible => '',
        AiTextProviderKind.openai => 'gpt-4o-mini',
        AiTextProviderKind.deepSeek => 'deepseek-chat',
        AiTextProviderKind.openRouter => 'openai/gpt-4o-mini',
        AiTextProviderKind.qwen => 'qwen-plus',
        AiTextProviderKind.siliconFlow => 'deepseek-ai/DeepSeek-V3',
        AiTextProviderKind.moonshot => 'kimi-latest',
        AiTextProviderKind.zai => 'glm-4',
        AiTextProviderKind.miniMax => 'MiniMax-M2',
        AiTextProviderKind.ollama => 'llama3.2',
      };

  bool get needsApiKey => this != AiTextProviderKind.ollama;

  bool get supportsModelProbe => true;

  static AiTextProviderKind parse(String? raw) {
    return AiTextProviderKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => AiTextProviderKind.openAiCompatible,
    );
  }
}

/// Image providers. Inspired by NativeTavern `ImageGenProvider` (separate from LLM).
enum AiImageProviderKind {
  openAiCompatible,
  openai,
  openaiChat,
  siliconFlow,
  pollinations,
  novelai,
  automatic1111,
  comfyui,
}

extension AiImageProviderKindX on AiImageProviderKind {
  String get defaultBaseUrl => switch (this) {
        AiImageProviderKind.openAiCompatible => 'http://localhost:8080/v1',
        AiImageProviderKind.openai => 'https://api.openai.com/v1',
        AiImageProviderKind.openaiChat => 'https://api.openai.com/v1',
        AiImageProviderKind.siliconFlow => 'https://api.siliconflow.cn/v1',
        AiImageProviderKind.pollinations => 'https://image.pollinations.ai',
        AiImageProviderKind.novelai => 'https://image.novelai.net',
        AiImageProviderKind.automatic1111 => 'http://localhost:7860',
        AiImageProviderKind.comfyui => 'http://127.0.0.1:8188',
      };

  String get defaultModel => switch (this) {
        AiImageProviderKind.openAiCompatible => '',
        AiImageProviderKind.openai => 'dall-e-3',
        AiImageProviderKind.openaiChat => 'gpt-image-1',
        AiImageProviderKind.siliconFlow => '',
        AiImageProviderKind.pollinations => 'flux',
        AiImageProviderKind.novelai => 'nai-diffusion-4-5-curated',
        AiImageProviderKind.automatic1111 => '',
        AiImageProviderKind.comfyui => '',
      };

  bool get needsApiKey => switch (this) {
        AiImageProviderKind.pollinations ||
        AiImageProviderKind.automatic1111 ||
        AiImageProviderKind.comfyui =>
          false,
        _ => true,
      };

  /// OpenAI-compatible `/models`, or ComfyUI `/models/checkpoints`.
  bool get supportsModelProbe => switch (this) {
        AiImageProviderKind.openAiCompatible ||
        AiImageProviderKind.openai ||
        AiImageProviderKind.openaiChat ||
        AiImageProviderKind.siliconFlow ||
        AiImageProviderKind.comfyui =>
          true,
        _ => false,
      };

  List<String> get fallbackModels => switch (this) {
        AiImageProviderKind.openai => const ['dall-e-3', 'dall-e-2', 'gpt-image-1'],
        AiImageProviderKind.openaiChat =>
          const ['gpt-image-1', 'gpt-image-1-mini'],
        AiImageProviderKind.pollinations => const ['flux', 'turbo'],
        AiImageProviderKind.novelai => const [
            'nai-diffusion-4-5-curated',
            'nai-diffusion-4-5-full',
          ],
        _ => const <String>[],
      };

  static AiImageProviderKind parse(String? raw) {
    // Migrate old text-provider kinds saved on the image channel.
    final migrated = switch (raw) {
      'deepSeek' ||
      'openRouter' ||
      'qwen' ||
      'moonshot' ||
      'zai' ||
      'miniMax' ||
      'ollama' =>
        AiImageProviderKind.openAiCompatible,
      _ => null,
    };
    if (migrated != null) return migrated;
    return AiImageProviderKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => AiImageProviderKind.openAiCompatible,
    );
  }
}

/// Reasoning / thinking budget for text models (aligned with NT `ReasoningEffort`).
enum AiReasoningEffort {
  auto,
  min,
  low,
  medium,
  high,
  max;

  /// OpenAI-compatible `reasoning_effort` value; `null` means omit the field.
  String? get openAiReasoningEffort => switch (this) {
        auto => null,
        min => 'minimal',
        low => 'low',
        medium => 'medium',
        high => 'high',
        max => 'high',
      };

  /// OpenRouter nested `reasoning.effort` (low / medium / high).
  String? get openRouterEffort => switch (this) {
        auto => null,
        min || low => 'low',
        medium => 'medium',
        high || max => 'high',
      };

  static AiReasoningEffort parse(String? raw) {
    if (raw == null || raw.isEmpty) return auto;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return auto;
  }

  /// Tolerates hot-reload / legacy in-memory nulls.
  static AiReasoningEffort coerce(Object? value) {
    if (value is AiReasoningEffort) return value;
    if (value is String) return parse(value);
    return auto;
  }
}

/// Active text endpoint.
class AiTextEndpoint {
  const AiTextEndpoint({
    this.kind = AiTextProviderKind.openAiCompatible,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    AiReasoningEffort reasoningEffort = AiReasoningEffort.auto,
  }) : _reasoningEffort = reasoningEffort;

  final AiTextProviderKind kind;
  final String baseUrl;
  final String apiKey;
  final String model;

  /// Nullable storage so hot-reload / legacy instances with a null slot
  /// do not crash when read through a non-null field getter.
  final AiReasoningEffort? _reasoningEffort;

  AiReasoningEffort get reasoningEffort =>
      AiReasoningEffort.coerce(_reasoningEffort);

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  bool get needsApiKey => kind.needsApiKey;
  bool get supportsModelProbe => kind.supportsModelProbe;

  AiTextEndpoint copyWith({
    AiTextProviderKind? kind,
    String? baseUrl,
    String? apiKey,
    String? model,
    AiReasoningEffort? reasoningEffort,
  }) {
    return AiTextEndpoint(
      kind: kind ?? this.kind,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    );
  }

  AiTextEndpoint switchKind(AiTextProviderKind next, {AiTextEndpoint? saved}) {
    if (saved != null && saved.kind == next) return saved;
    return AiTextEndpoint(
      kind: next,
      baseUrl: next.defaultBaseUrl,
      apiKey: '',
      model: next.defaultModel,
      reasoningEffort: reasoningEffort,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'reasoningEffort': reasoningEffort.name,
      };

  factory AiTextEndpoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiTextEndpoint();
    if (json.containsKey('providers')) {
      return AiTextEndpoint.fromJson(_activeFromProviders(json));
    }
    return AiTextEndpoint(
      kind: AiTextProviderKindX.parse(json.optionalString('kind')),
      baseUrl: json.optionalString('baseUrl') ?? '',
      apiKey: json.optionalString('apiKey') ?? '',
      model: json.optionalString('model') ?? '',
      reasoningEffort: AiReasoningEffort.parse(
        json.optionalString('reasoningEffort'),
      ),
    );
  }
}

/// Named latent size for the settings preset sheet (multiples of 64).
class ImageGenSizePreset {
  const ImageGenSizePreset({
    required this.width,
    required this.height,
    required this.aspectLabel,
  });

  final int width;
  final int height;

  /// User-facing ratio tag, e.g. `16:9` / `2:3`.
  final String aspectLabel;

  String get sizeLabel => '$width×$height';
}

/// Built-in size catalogs for portrait / scene (Comfy / SDXL friendly).
///
/// Width and height are always multiples of [AiImageEndpoint.sizeStep].
abstract final class ImageGenSizePresets {
  static const List<ImageGenSizePreset> portrait = <ImageGenSizePreset>[
    ImageGenSizePreset(width: 512, height: 768, aspectLabel: '2:3'),
    ImageGenSizePreset(width: 640, height: 960, aspectLabel: '2:3'),
    ImageGenSizePreset(width: 768, height: 1152, aspectLabel: '2:3'),
    ImageGenSizePreset(width: 832, height: 1216, aspectLabel: '2:3'),
    ImageGenSizePreset(width: 896, height: 1344, aspectLabel: '2:3'),
    ImageGenSizePreset(width: 1024, height: 1024, aspectLabel: '1:1'),
  ];

  static const List<ImageGenSizePreset> scene = <ImageGenSizePreset>[
    ImageGenSizePreset(width: 1024, height: 576, aspectLabel: '16:9'),
    ImageGenSizePreset(width: 1152, height: 640, aspectLabel: '16:9'),
    ImageGenSizePreset(width: 1280, height: 704, aspectLabel: '16:9'),
    ImageGenSizePreset(width: 1344, height: 768, aspectLabel: '16:9'),
    ImageGenSizePreset(width: 1536, height: 896, aspectLabel: '16:9'),
    ImageGenSizePreset(width: 1920, height: 1088, aspectLabel: '16:9'),
    ImageGenSizePreset(width: 768, height: 512, aspectLabel: '3:2'),
    ImageGenSizePreset(width: 1216, height: 832, aspectLabel: '3:2'),
    ImageGenSizePreset(width: 1024, height: 1024, aspectLabel: '1:1'),
  ];
}

/// Active image endpoint (providers differ from text).
class AiImageEndpoint {
  const AiImageEndpoint({
    this.kind = AiImageProviderKind.openAiCompatible,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.lora = defaultLora,
    this.loraStrength = defaultLoraStrength,
    this.steps = defaultSteps,
    this.upscale = defaultUpscale,
    this.portraitWidth = defaultPortraitWidth,
    this.portraitHeight = defaultPortraitHeight,
    this.sceneWidth = defaultSceneWidth,
    this.sceneHeight = defaultSceneHeight,
  });

  /// Comfy / diffusion sampling steps (fewer = faster, softer detail).
  static const int defaultSteps = 12;
  static const int stepsLowerBound = 4;
  static const int stepsUpperBound = 40;
  static const bool defaultUpscale = false;

  /// Default style LoRA filename under ComfyUI `models/loras/`.
  static const String defaultLora = 'RLI(noobai)0.1v.safetensors';
  static const double defaultLoraStrength = 0.85;
  static const double loraStrengthLowerBound = 0.0;
  static const double loraStrengthUpperBound = 1.5;

  static const int defaultPortraitWidth = 768;
  static const int defaultPortraitHeight = 1152;
  static const int defaultSceneWidth = 1216;
  static const int defaultSceneHeight = 832;

  static const int sizeLowerBound = 256;
  static const int sizeUpperBound = 2048;
  static const int sizeStep = 64;

  static int clampSteps(int value) =>
      value.clamp(stepsLowerBound, stepsUpperBound);

  static double clampLoraStrength(double value) =>
      value.clamp(loraStrengthLowerBound, loraStrengthUpperBound);

  /// Snap to [sizeStep] within [sizeLowerBound]…[sizeUpperBound].
  static int clampSize(int value) {
    final clamped = value.clamp(sizeLowerBound, sizeUpperBound);
    final snapped = ((clamped + sizeStep ~/ 2) ~/ sizeStep) * sizeStep;
    return snapped.clamp(sizeLowerBound, sizeUpperBound);
  }

  final AiImageProviderKind kind;
  final String baseUrl;
  final String apiKey;
  final String model;

  /// ComfyUI LoRA filename; empty = do not load a LoRA.
  final String lora;

  final double loraStrength;

  /// Sampling steps for ComfyUI workflows.
  final int steps;

  /// Run RealESRGAN after decode (much slower on local AMD).
  final bool upscale;

  final int portraitWidth;
  final int portraitHeight;
  final int sceneWidth;
  final int sceneHeight;

  /// Non-empty LoRA name for workflows, or null to omit the loader node.
  String? get resolvedLoraName {
    final name = lora.trim();
    return name.isEmpty ? null : name;
  }

  /// ComfyUI only needs a reachable base URL (checkpoint lives in workflow).
  bool get isConfigured {
    if (baseUrl.trim().isEmpty) return false;
    if (kind == AiImageProviderKind.comfyui) return true;
    return model.trim().isNotEmpty;
  }

  bool get needsApiKey => kind.needsApiKey;
  bool get supportsModelProbe => kind.supportsModelProbe;

  AiImageEndpoint copyWith({
    AiImageProviderKind? kind,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? lora,
    bool clearLora = false,
    double? loraStrength,
    int? steps,
    bool? upscale,
    int? portraitWidth,
    int? portraitHeight,
    int? sceneWidth,
    int? sceneHeight,
  }) {
    return AiImageEndpoint(
      kind: kind ?? this.kind,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      lora: clearLora ? '' : (lora ?? this.lora),
      loraStrength: clampLoraStrength(loraStrength ?? this.loraStrength),
      steps: clampSteps(steps ?? this.steps),
      upscale: upscale ?? this.upscale,
      portraitWidth: clampSize(portraitWidth ?? this.portraitWidth),
      portraitHeight: clampSize(portraitHeight ?? this.portraitHeight),
      sceneWidth: clampSize(sceneWidth ?? this.sceneWidth),
      sceneHeight: clampSize(sceneHeight ?? this.sceneHeight),
    );
  }

  AiImageEndpoint switchKind(
    AiImageProviderKind next, {
    AiImageEndpoint? saved,
  }) {
    if (saved != null && saved.kind == next) return saved;
    return AiImageEndpoint(
      kind: next,
      baseUrl: next.defaultBaseUrl,
      apiKey: '',
      model: next.defaultModel,
      lora: next == AiImageProviderKind.comfyui ? defaultLora : '',
      loraStrength: loraStrength,
      steps: steps,
      upscale: upscale,
      portraitWidth: portraitWidth,
      portraitHeight: portraitHeight,
      sceneWidth: sceneWidth,
      sceneHeight: sceneHeight,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'lora': lora,
        'loraStrength': loraStrength,
        'steps': steps,
        'upscale': upscale,
        'portraitWidth': portraitWidth,
        'portraitHeight': portraitHeight,
        'sceneWidth': sceneWidth,
        'sceneHeight': sceneHeight,
      };

  factory AiImageEndpoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiImageEndpoint();
    if (json.containsKey('providers')) {
      return AiImageEndpoint.fromJson(_activeFromProviders(json));
    }
    final legacy = _legacyResolutionSizes(json.optionalString('resolution'));
    final kind = AiImageProviderKindX.parse(json.optionalString('kind'));
    final rawLora = json.optionalString('lora');
    return AiImageEndpoint(
      kind: kind,
      baseUrl: json.optionalString('baseUrl') ?? '',
      apiKey: json.optionalString('apiKey') ?? '',
      model: json.optionalString('model') ?? '',
      // Missing key → keep RLI default for Comfy; explicit "" stays off.
      lora: rawLora ??
          (kind == AiImageProviderKind.comfyui ? defaultLora : ''),
      loraStrength: clampLoraStrength(
        (json.optionalNum('loraStrength') ?? defaultLoraStrength).toDouble(),
      ),
      steps: clampSteps(
        (json.optionalNum('steps') ?? defaultSteps).toInt(),
      ),
      upscale: json.optionalBool('upscale') ?? defaultUpscale,
      portraitWidth: clampSize(
        (json.optionalNum('portraitWidth') ?? legacy.$1.$1).toInt(),
      ),
      portraitHeight: clampSize(
        (json.optionalNum('portraitHeight') ?? legacy.$1.$2).toInt(),
      ),
      sceneWidth: clampSize(
        (json.optionalNum('sceneWidth') ?? legacy.$2.$1).toInt(),
      ),
      sceneHeight: clampSize(
        (json.optionalNum('sceneHeight') ?? legacy.$2.$2).toInt(),
      ),
    );
  }

  /// Maps retired small/medium/large wire values onto concrete sizes.
  static ((int, int), (int, int)) _legacyResolutionSizes(String? raw) {
    return switch (raw) {
      'small' => ((512, 768), (768, 512)),
      'large' => ((832, 1216), (1344, 768)),
      _ => (
          (defaultPortraitWidth, defaultPortraitHeight),
          (defaultSceneWidth, defaultSceneHeight),
        ),
    };
  }
}

Map<String, dynamic>? _activeFromProviders(Map<String, dynamic> json) {
  final rawList = json.optionalList('providers');
  final activeId = json.optionalString('activeId');
  Map<String, dynamic>? chosen;
  for (final item in rawList) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    chosen ??= map;
    if (activeId != null && map.optionalString('id') == activeId) {
      chosen = map;
      break;
    }
  }
  return chosen;
}

class AiSettings {
  const AiSettings({
    this.text = const AiTextEndpoint(),
    this.image = const AiImageEndpoint(),
    this.textSlots = const <String, AiTextEndpoint>{},
    this.imageSlots = const <String, AiImageEndpoint>{},
    this.generation = const GenerationPreset(),
    this.minBridgeLines = defaultMinBridgeLines,
    this.minGraphStations = defaultMinGraphStations,
    this.maxInStationChoices = defaultMaxInStationChoices,
  });

  /// VN interval generation: minimum lines (dialogue + narration) per beat.
  static const int defaultMinBridgeLines = 10;
  static const int minBridgeLinesLowerBound = 1;
  static const int minBridgeLinesUpperBound = 10;

  /// Full plot skeleton: minimum stations the model must produce.
  static const int defaultMinGraphStations = 20;
  static const int minGraphStationsLowerBound = 4;
  static const int minGraphStationsUpperBound = 60;

  /// Max player choices when a beat branches (can be fewer; never more).
  static const int defaultMaxInStationChoices = 3;
  static const int maxInStationChoicesLowerBound = 1;
  static const int maxInStationChoicesUpperBound = 4;

  static int clampMinBridgeLines(int value) =>
      value.clamp(minBridgeLinesLowerBound, minBridgeLinesUpperBound);

  static int clampMinGraphStations(int value) =>
      value.clamp(minGraphStationsLowerBound, minGraphStationsUpperBound);

  static int clampMaxInStationChoices(int value) =>
      value.clamp(maxInStationChoicesLowerBound, maxInStationChoicesUpperBound);

  final AiTextEndpoint text;
  final AiImageEndpoint image;
  final Map<String, AiTextEndpoint> textSlots;
  final Map<String, AiImageEndpoint> imageSlots;

  /// Active sampler params (from applied ST preset or manual tweaks).
  final GenerationPreset generation;

  /// Asked of the model every VN beat; short outputs are retried once.
  final int minBridgeLines;

  /// Asked of create / replace-graph: minimum stations in a full skeleton.
  final int minGraphStations;

  /// Cap on choices per AI beat when branching (1–4; empty choices still OK).
  final int maxInStationChoices;

  AiSettings copyWith({
    AiTextEndpoint? text,
    AiImageEndpoint? image,
    Map<String, AiTextEndpoint>? textSlots,
    Map<String, AiImageEndpoint>? imageSlots,
    GenerationPreset? generation,
    int? minBridgeLines,
    int? minGraphStations,
    int? maxInStationChoices,
  }) {
    return AiSettings(
      text: text ?? this.text,
      image: image ?? this.image,
      textSlots: textSlots ?? this.textSlots,
      imageSlots: imageSlots ?? this.imageSlots,
      generation: generation ?? this.generation,
      minBridgeLines: clampMinBridgeLines(
        minBridgeLines ?? this.minBridgeLines,
      ),
      minGraphStations: clampMinGraphStations(
        minGraphStations ?? this.minGraphStations,
      ),
      maxInStationChoices: clampMaxInStationChoices(
        maxInStationChoices ?? this.maxInStationChoices,
      ),
    );
  }

  AiSettings withText(AiTextEndpoint next) {
    final slots = Map<String, AiTextEndpoint>.from(textSlots)
      ..[next.kind.name] = next;
    return copyWith(text: next, textSlots: slots);
  }

  AiSettings withImage(AiImageEndpoint next) {
    final slots = Map<String, AiImageEndpoint>.from(imageSlots)
      ..[next.kind.name] = next;
    return copyWith(image: next, imageSlots: slots);
  }

  AiSettings switchTextKind(AiTextProviderKind kind) {
    final saved = textSlots[kind.name];
    final next = text.switchKind(kind, saved: saved);
    final slots = Map<String, AiTextEndpoint>.from(textSlots)
      ..[text.kind.name] = text;
    return copyWith(text: next, textSlots: slots);
  }

  AiSettings switchImageKind(AiImageProviderKind kind) {
    final saved = imageSlots[kind.name];
    final next = image.switchKind(kind, saved: saved);
    final slots = Map<String, AiImageEndpoint>.from(imageSlots)
      ..[image.kind.name] = image;
    return copyWith(image: next, imageSlots: slots);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text.toJson(),
        'image': image.toJson(),
        'textSlots': {
          for (final e in textSlots.entries) e.key: e.value.toJson(),
        },
        'imageSlots': {
          for (final e in imageSlots.entries) e.key: e.value.toJson(),
        },
        'generation': generation.toJson(),
        'minBridgeLines': minBridgeLines,
        'minGraphStations': minGraphStations,
        'maxInStationChoices': maxInStationChoices,
      };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final genMap = json.optionalMap('generation');
    return AiSettings(
      text: AiTextEndpoint.fromJson(json.optionalMap('text')),
      image: AiImageEndpoint.fromJson(json.optionalMap('image')),
      textSlots: _textSlotsFromJson(json.optionalMap('textSlots')),
      imageSlots: _imageSlotsFromJson(json.optionalMap('imageSlots')),
      generation: genMap == null
          ? const GenerationPreset()
          : GenerationPreset.fromJson(genMap),
      minBridgeLines: clampMinBridgeLines(
        (json.optionalNum('minBridgeLines') ?? defaultMinBridgeLines).toInt(),
      ),
      minGraphStations: clampMinGraphStations(
        (json.optionalNum('minGraphStations') ?? defaultMinGraphStations)
            .toInt(),
      ),
      maxInStationChoices: clampMaxInStationChoices(
        (json.optionalNum('maxInStationChoices') ?? defaultMaxInStationChoices)
            .toInt(),
      ),
    );
  }

  static Map<String, AiTextEndpoint> _textSlotsFromJson(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return const {};
    final out = <String, AiTextEndpoint>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      out[entry.key] =
          AiTextEndpoint.fromJson(Map<String, dynamic>.from(value));
    }
    return out;
  }

  static Map<String, AiImageEndpoint> _imageSlotsFromJson(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return const {};
    final out = <String, AiImageEndpoint>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      out[entry.key] =
          AiImageEndpoint.fromJson(Map<String, dynamic>.from(value));
    }
    return out;
  }
}

/// Compatibility alias used by model catalog HTTP layer.
class AiEndpointConfig {
  const AiEndpointConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.needsApiKey,
    this.defaultBaseUrl = '',
    this.imageKind,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final bool needsApiKey;
  final String defaultBaseUrl;

  /// When set, catalog may use provider-specific list endpoints.
  final AiImageProviderKind? imageKind;

  factory AiEndpointConfig.fromText(AiTextEndpoint e) => AiEndpointConfig(
        baseUrl: e.baseUrl,
        apiKey: e.apiKey,
        model: e.model,
        needsApiKey: e.needsApiKey,
        defaultBaseUrl: e.kind.defaultBaseUrl,
      );

  factory AiEndpointConfig.fromImage(AiImageEndpoint e) => AiEndpointConfig(
        baseUrl: e.baseUrl,
        apiKey: e.apiKey,
        model: e.model,
        needsApiKey: e.needsApiKey,
        defaultBaseUrl: e.kind.defaultBaseUrl,
        imageKind: e.kind,
      );
}
