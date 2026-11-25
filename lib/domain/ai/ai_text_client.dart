import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/think_tag_stream_filter.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

/// Text completion with optional chain-of-thought.
class AiTextCompletion {
  const AiTextCompletion({
    required this.content,
    this.reasoning,
  });

  final String content;
  final String? reasoning;
}

/// One incremental piece of a streamed text completion.
class AiTextChunk {
  const AiTextChunk({this.content = '', this.reasoning = ''});

  final String content;
  final String reasoning;

  bool get isEmpty => content.isEmpty && reasoning.isEmpty;
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

/// Capability: one text turn delivered as it is written.
///
/// Kept apart from [AiTextClient] so simple callers (and their fakes) do not
/// have to implement streaming at all — they check `is AiTextStreamClient`
/// and fall back to [AiTextClient.complete].
abstract class AiTextStreamClient {
  Stream<AiTextChunk> streamText({
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
class EndpointAiTextClient implements AiTextClient, AiTextStreamClient,
    AiToolTurnClient {
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

  @override
  Stream<AiTextChunk> streamText({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async* {
    final openRouter = endpoint.kind == AiTextProviderKind.openRouter;
    final effort = endpoint.reasoningEffort;
    final filter = ThinkTagStreamFilter();
    var activeGeneration = generation;
    var retriedWithoutJson = false;
    while (true) {
      var yielded = false;
      try {
        await for (final delta in _chat.stream(
          baseUrl: endpoint.baseUrl,
          fallbackBaseUrl: endpoint.kind.defaultBaseUrl,
          apiKey: endpoint.apiKey,
          needsApiKey: endpoint.needsApiKey,
          model: endpoint.model,
          generation: activeGeneration,
          reasoningEffort: openRouter ? null : effort.openAiReasoningEffort,
          reasoning: openRouter && effort.openRouterEffort != null
              ? <String, dynamic>{'effort': effort.openRouterEffort}
              : null,
          messages: <OpenAiChatMessage>[
            OpenAiChatMessage(role: 'system', content: system),
            OpenAiChatMessage(role: 'user', content: user),
          ],
        )) {
          final split = filter.add(delta.content);
          final reasoning = '${delta.reasoning}${split.$2}';
          if (split.$1.isEmpty && reasoning.isEmpty) continue;
          yielded = true;
          yield AiTextChunk(content: split.$1, reasoning: reasoning);
        }
        break;
      } on OpenAiChatException catch (error) {
        if (!yielded &&
            !retriedWithoutJson &&
            activeGeneration?.jsonObject == true &&
            _looksLikeJsonFormatReject(error.message)) {
          AppLog.instance.warning(
            '服务不支持 JSON 模式，改用不强制格式再试',
            tag: 'ai.text',
          );
          activeGeneration = activeGeneration!.copyWith(jsonObject: false);
          retriedWithoutJson = true;
          continue;
        }
        throw AiTextException(error.message, code: error.code);
      }
    }
    final tail = filter.flush();
    if (tail.$1.isEmpty && tail.$2.isEmpty) return;
    yield AiTextChunk(content: tail.$1, reasoning: tail.$2);
  }

  Future<OpenAiChatCompletion> _send({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    required GenerationPreset? generation,
    List<OpenAiTool> tools = const <OpenAiTool>[],
  }) async {
    final openRouter = endpoint.kind == AiTextProviderKind.openRouter;
    final effort = endpoint.reasoningEffort;
    var activeGeneration = generation;
    var retriedWithoutJson = false;
    while (true) {
      try {
        return await _chat.complete(
          baseUrl: endpoint.baseUrl,
          fallbackBaseUrl: endpoint.kind.defaultBaseUrl,
          apiKey: endpoint.apiKey,
          needsApiKey: endpoint.needsApiKey,
          model: endpoint.model,
          generation: activeGeneration,
          reasoningEffort:
              openRouter ? null : effort.openAiReasoningEffort,
          reasoning: openRouter && effort.openRouterEffort != null
              ? <String, dynamic>{'effort': effort.openRouterEffort}
              : null,
          messages: messages,
          tools: tools,
        );
      } on OpenAiChatException catch (error) {
        if (!retriedWithoutJson &&
            activeGeneration?.jsonObject == true &&
            _looksLikeJsonFormatReject(error.message)) {
          AppLog.instance.warning(
            '服务不支持 JSON 模式，改用不强制格式再试',
            tag: 'ai.text',
          );
          activeGeneration = activeGeneration!.copyWith(jsonObject: false);
          retriedWithoutJson = true;
          continue;
        }
        throw AiTextException(error.message, code: error.code);
      }
    }
  }

  /// Heuristic: provider complained about response_format / json_object.
  static bool _looksLikeJsonFormatReject(String message) {
    final lower = message.toLowerCase();
    return lower.contains('response_format') ||
        lower.contains('json_object') ||
        lower.contains('json mode') ||
        message.contains('响应格式') ||
        (lower.contains('json') && message.contains('不支持'));
  }
}
