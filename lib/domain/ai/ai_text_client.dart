import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';

/// Text completion with optional chain-of-thought.
class AiTextCompletion {
  const AiTextCompletion({
    required this.content,
    this.reasoning,
  });

  final String content;
  final String? reasoning;
}

/// Business-facing text completion over the active [AiTextEndpoint].
abstract class AiTextClient {
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  });
}

/// Capability: one model turn that may answer with text or ask to call tools.
///
/// Kept apart from [AiTextClient] so simple one-shot callers (and their fakes)
/// do not have to know about tool calling at all.
abstract class AiToolTurnClient {
  Future<OpenAiChatCompletion> completeTurn({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    List<OpenAiTool> tools = const <OpenAiTool>[],
    GenerationPreset? generation,
  });
}

class AiTextException implements Exception {
  AiTextException(this.message, {this.code});

  final String message;

  /// Machine-readable cause when the provider said why a reply was unusable
  /// (`truncated`, `thinking_only`, `empty`): callers can retry smaller
  /// instead of only showing text. Mirrors [OpenAiChatException.code].
  final String? code;

  /// Output hit the reply-token limit: the useful part is missing.
  static const String truncated = 'truncated';

  @override
  String toString() => message;
}

/// Adapts [OpenAiChatClient] to [AiTextEndpoint] settings.
class EndpointAiTextClient implements AiTextClient, AiToolTurnClient {
  EndpointAiTextClient({OpenAiChatClient? chat})
      : _chat = chat ?? OpenAiChatClient();

  final OpenAiChatClient _chat;

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    final result = await _send(
      endpoint: endpoint,
      messages: <OpenAiChatMessage>[
        OpenAiChatMessage(role: 'system', content: system),
        OpenAiChatMessage(role: 'user', content: user),
      ],
      generation: generation,
    );
    return AiTextCompletion(
      content: result.content,
      reasoning: result.reasoning,
    );
  }

  @override
  Future<OpenAiChatCompletion> completeTurn({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    List<OpenAiTool> tools = const <OpenAiTool>[],
    GenerationPreset? generation,
  }) {
    return _send(
      endpoint: endpoint,
      messages: messages,
      generation: generation,
      tools: tools,
    );
  }

  Future<OpenAiChatCompletion> _send({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    required GenerationPreset? generation,
    List<OpenAiTool> tools = const <OpenAiTool>[],
  }) async {
    final openRouter = endpoint.kind == AiTextProviderKind.openRouter;
    final effort = endpoint.reasoningEffort;
    try {
      return await _chat.complete(
        baseUrl: endpoint.baseUrl,
        fallbackBaseUrl: endpoint.kind.defaultBaseUrl,
        apiKey: endpoint.apiKey,
        needsApiKey: endpoint.needsApiKey,
        model: endpoint.model,
        generation: generation,
        reasoningEffort:
            openRouter ? null : effort.openAiReasoningEffort,
        reasoning: openRouter && effort.openRouterEffort != null
            ? <String, dynamic>{'effort': effort.openRouterEffort}
            : null,
        messages: messages,
        tools: tools,
      );
    } on OpenAiChatException catch (error) {
      throw AiTextException(error.message, code: error.code);
    }
  }
}
