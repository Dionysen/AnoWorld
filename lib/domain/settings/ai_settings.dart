import 'package:anoworld/domain/models/json_map.dart';

/// One OpenAI-compatible style endpoint (text or image).
class AiEndpointConfig {
  const AiEndpointConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  AiEndpointConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return AiEndpointConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory AiEndpointConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiEndpointConfig();
    return AiEndpointConfig(
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
  });

  final AiEndpointConfig text;
  final AiEndpointConfig image;

  AiSettings copyWith({
    AiEndpointConfig? text,
    AiEndpointConfig? image,
  }) {
    return AiSettings(
      text: text ?? this.text,
      image: image ?? this.image,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text.toJson(),
        'image': image.toJson(),
      };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      text: AiEndpointConfig.fromJson(json.optionalMap('text')),
      image: AiEndpointConfig.fromJson(json.optionalMap('image')),
    );
  }
}
