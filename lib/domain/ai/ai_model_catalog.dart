import 'package:anoworld/domain/settings/ai_settings.dart';

/// Lists models from a configured AI endpoint (OpenAI-compatible `/models`).
abstract class AiModelCatalog {
  Future<List<String>> listModels(AiEndpointConfig endpoint);

  /// ComfyUI `GET /models/loras`. Other providers return an empty list.
  Future<List<String>> listLoras(AiEndpointConfig endpoint);
}

class AiModelCatalogException implements Exception {
  AiModelCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
