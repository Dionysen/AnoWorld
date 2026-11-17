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
  String get label => switch (this) {
        AiTextProviderKind.openAiCompatible => '自定义',
        AiTextProviderKind.openai => 'OpenAI',
        AiTextProviderKind.deepSeek => 'DeepSeek',
        AiTextProviderKind.openRouter => 'OpenRouter',
        AiTextProviderKind.qwen => '通义千问',
        AiTextProviderKind.siliconFlow => '硅基流动',
        AiTextProviderKind.moonshot => 'Moonshot',
        AiTextProviderKind.zai => '智谱',
        AiTextProviderKind.miniMax => 'MiniMax',
        AiTextProviderKind.ollama => 'Ollama',
      };

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
  String get label => switch (this) {
        AiImageProviderKind.openAiCompatible => '自定义 / OAI 生图',
        AiImageProviderKind.openai => 'OpenAI Images',
        AiImageProviderKind.openaiChat => 'OAI Chat 生图',
        AiImageProviderKind.siliconFlow => '硅基流动',
        AiImageProviderKind.pollinations => 'Pollinations（免费）',
        AiImageProviderKind.novelai => 'NovelAI',
        AiImageProviderKind.automatic1111 => 'Automatic1111',
        AiImageProviderKind.comfyui => 'ComfyUI',
      };

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

  /// OpenAI-compatible `/models` probe; locals often need other endpoints later.
  bool get supportsModelProbe => switch (this) {
        AiImageProviderKind.openAiCompatible ||
        AiImageProviderKind.openai ||
        AiImageProviderKind.openaiChat ||
        AiImageProviderKind.siliconFlow =>
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

  /// User-facing short label.
  String get label => switch (this) {
        auto => '自动',
        min => '最低',
        low => '低',
        medium => '中',
        high => '高',
        max => '最高',
      };

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

/// Active image endpoint (providers differ from text).
class AiImageEndpoint {
  const AiImageEndpoint({
    this.kind = AiImageProviderKind.openAiCompatible,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
  });

  final AiImageProviderKind kind;
  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  bool get needsApiKey => kind.needsApiKey;
  bool get supportsModelProbe => kind.supportsModelProbe;

  AiImageEndpoint copyWith({
    AiImageProviderKind? kind,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return AiImageEndpoint(
      kind: kind ?? this.kind,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
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
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory AiImageEndpoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiImageEndpoint();
    if (json.containsKey('providers')) {
      return AiImageEndpoint.fromJson(_activeFromProviders(json));
    }
    return AiImageEndpoint(
      kind: AiImageProviderKindX.parse(json.optionalString('kind')),
      baseUrl: json.optionalString('baseUrl') ?? '',
      apiKey: json.optionalString('apiKey') ?? '',
      model: json.optionalString('model') ?? '',
    );
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
  });

  final AiTextEndpoint text;
  final AiImageEndpoint image;
  final Map<String, AiTextEndpoint> textSlots;
  final Map<String, AiImageEndpoint> imageSlots;

  /// Active sampler params (from applied ST preset or manual tweaks).
  final GenerationPreset generation;

  AiSettings copyWith({
    AiTextEndpoint? text,
    AiImageEndpoint? image,
    Map<String, AiTextEndpoint>? textSlots,
    Map<String, AiImageEndpoint>? imageSlots,
    GenerationPreset? generation,
  }) {
    return AiSettings(
      text: text ?? this.text,
      image: image ?? this.image,
      textSlots: textSlots ?? this.textSlots,
      imageSlots: imageSlots ?? this.imageSlots,
      generation: generation ?? this.generation,
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
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final bool needsApiKey;
  final String defaultBaseUrl;

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
      );
}
