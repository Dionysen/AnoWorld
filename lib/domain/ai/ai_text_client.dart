import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';

/// Business-facing text completion over the active [AiTextEndpoint].
abstract class AiTextClient {
  Future<String> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  });
}

class AiTextException implements Exception {
  AiTextException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Adapts [OpenAiChatClient] to [AiTextEndpoint] settings.
class EndpointAiTextClient implements AiTextClient {
  EndpointAiTextClient({OpenAiChatClient? chat})
      : _chat = chat ?? OpenAiChatClient();

  final OpenAiChatClient _chat;

  @override
  Future<String> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    try {
      return await _chat.complete(
        baseUrl: endpoint.baseUrl,
        fallbackBaseUrl: endpoint.kind.defaultBaseUrl,
        apiKey: endpoint.apiKey,
        needsApiKey: endpoint.needsApiKey,
        model: endpoint.model,
        generation: generation,
        messages: <OpenAiChatMessage>[
          OpenAiChatMessage(role: 'system', content: system),
          OpenAiChatMessage(role: 'user', content: user),
        ],
      );
    } on OpenAiChatException catch (error) {
      throw AiTextException(error.message);
    }
  }
}
