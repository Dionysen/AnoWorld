import 'package:anoworld/domain/models/json_map.dart';

/// Built-in provider templates (OpenAI-compatible HTTP). Inspired by NativeTavern.
enum AiProviderKind {
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

extension AiProviderKindX on AiProviderKind {
  String get label => switch (this) {
        AiProviderKind.openAiCompatible => '自定义',
        AiProviderKind.openai => 'OpenAI',
        AiProviderKind.deepSeek => 'DeepSeek',
        AiProviderKind.openRouter => 'OpenRouter',
        AiProviderKind.qwen => '通义千问',
        AiProviderKind.siliconFlow => '硅基流动',
        AiProviderKind.moonshot => 'Moonshot',
        AiProviderKind.zai => '智谱',
        AiProviderKind.miniMax => 'MiniMax',
        AiProviderKind.ollama => 'Ollama',
      };

  String get defaultBaseUrl => switch (this) {
        AiProviderKind.openAiCompatible => 'http://localhost:8080/v1',
        AiProviderKind.openai => 'https://api.openai.com/v1',
        AiProviderKind.deepSeek => 'https://api.deepseek.com/v1',
        AiProviderKind.openRouter => 'https://openrouter.ai/api/v1',
        AiProviderKind.qwen =>
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
        AiProviderKind.siliconFlow => 'https://api.siliconflow.cn/v1',
        AiProviderKind.moonshot => 'https://api.moonshot.cn/v1',
        AiProviderKind.zai => 'https://open.bigmodel.cn/api/paas/v4',
        AiProviderKind.miniMax => 'https://api.minimaxi.com/v1',
        AiProviderKind.ollama => 'http://localhost:11434/v1',
      };

  String defaultTextModel() => switch (this) {
        AiProviderKind.openAiCompatible => '',
        AiProviderKind.openai => 'gpt-4o-mini',
        AiProviderKind.deepSeek => 'deepseek-chat',
        AiProviderKind.openRouter => 'openai/gpt-4o-mini',
        AiProviderKind.qwen => 'qwen-plus',
        AiProviderKind.siliconFlow => 'deepseek-ai/DeepSeek-V3',
        AiProviderKind.moonshot => 'kimi-latest',
        AiProviderKind.zai => 'glm-4',
        AiProviderKind.miniMax => 'MiniMax-M2',
        AiProviderKind.ollama => 'llama3.2',
      };

  String defaultImageModel() => switch (this) {
        AiProviderKind.openai => 'dall-e-3',
        AiProviderKind.openAiCompatible => '',
        _ => '',
      };

  bool get needsApiKey => this != AiProviderKind.ollama;

  static AiProviderKind parse(String? raw) {
    return AiProviderKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => AiProviderKind.openAiCompatible,
    );
  }
}

/// Active endpoint for one channel (text or image).
class AiEndpointConfig {
  const AiEndpointConfig({
    this.kind = AiProviderKind.openAiCompatible,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
  });

  final AiProviderKind kind;
  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  AiEndpointConfig copyWith({
    AiProviderKind? kind,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return AiEndpointConfig(
      kind: kind ?? this.kind,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  /// Switch supplier: restore [saved] slot if any, else kind defaults.
  AiEndpointConfig switchKind(
    AiProviderKind next, {
    required bool forImage,
    AiEndpointConfig? saved,
  }) {
    if (saved != null && saved.kind == next) return saved;
    return AiEndpointConfig(
      kind: next,
      baseUrl: next.defaultBaseUrl,
      apiKey: '',
      model: forImage ? next.defaultImageModel() : next.defaultTextModel(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory AiEndpointConfig.fromJson(
    Map<String, dynamic>? json, {
    required bool forImage,
  }) {
    if (json == null) return const AiEndpointConfig();

    // Multi-provider format → active entry.
    if (json.containsKey('providers')) {
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
      return AiEndpointConfig.fromJson(chosen, forImage: forImage);
    }

    final kind = AiProviderKindX.parse(json.optionalString('kind'));
    return AiEndpointConfig(
      kind: kind,
      baseUrl: json.optionalString('baseUrl') ?? '',
      apiKey: json.optionalString('apiKey') ?? '',
      model: json.optionalString('model') ?? '',
    );
  }
}

class AiSettings {
  const AiSettings({
    this.text = const AiEndpointConfig(),
    this.image = const AiEndpointConfig(),
    this.textSlots = const <String, AiEndpointConfig>{},
    this.imageSlots = const <String, AiEndpointConfig>{},
  });

  final AiEndpointConfig text;
  final AiEndpointConfig image;

  /// Last-known fields per [AiProviderKind.name] when switching away.
  final Map<String, AiEndpointConfig> textSlots;
  final Map<String, AiEndpointConfig> imageSlots;

  AiSettings copyWith({
    AiEndpointConfig? text,
    AiEndpointConfig? image,
    Map<String, AiEndpointConfig>? textSlots,
    Map<String, AiEndpointConfig>? imageSlots,
  }) {
    return AiSettings(
      text: text ?? this.text,
      image: image ?? this.image,
      textSlots: textSlots ?? this.textSlots,
      imageSlots: imageSlots ?? this.imageSlots,
    );
  }

  AiSettings withText(AiEndpointConfig next) {
    final slots = Map<String, AiEndpointConfig>.from(textSlots)
      ..[next.kind.name] = next;
    return copyWith(text: next, textSlots: slots);
  }

  AiSettings withImage(AiEndpointConfig next) {
    final slots = Map<String, AiEndpointConfig>.from(imageSlots)
      ..[next.kind.name] = next;
    return copyWith(image: next, imageSlots: slots);
  }

  AiSettings switchTextKind(AiProviderKind kind) {
    final saved = textSlots[kind.name];
    final next = text.switchKind(kind, forImage: false, saved: saved);
    final slots = Map<String, AiEndpointConfig>.from(textSlots)
      ..[text.kind.name] = text;
    return copyWith(text: next, textSlots: slots);
  }

  AiSettings switchImageKind(AiProviderKind kind) {
    final saved = imageSlots[kind.name];
    final next = image.switchKind(kind, forImage: true, saved: saved);
    final slots = Map<String, AiEndpointConfig>.from(imageSlots)
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
      };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      text: AiEndpointConfig.fromJson(
        json.optionalMap('text'),
        forImage: false,
      ),
      image: AiEndpointConfig.fromJson(
        json.optionalMap('image'),
        forImage: true,
      ),
      textSlots: _slotsFromJson(json.optionalMap('textSlots'), forImage: false),
      imageSlots:
          _slotsFromJson(json.optionalMap('imageSlots'), forImage: true),
    );
  }

  static Map<String, AiEndpointConfig> _slotsFromJson(
    Map<String, dynamic>? raw, {
    required bool forImage,
  }) {
    if (raw == null) return const {};
    final out = <String, AiEndpointConfig>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      out[entry.key] = AiEndpointConfig.fromJson(
        Map<String, dynamic>.from(value),
        forImage: forImage,
      );
    }
    return out;
  }
}
