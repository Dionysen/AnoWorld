import 'dart:convert';

import 'package:anoworld/foundation/ai/openai_base_url.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/think_tag_parser.dart';
import 'package:http/http.dart' as http;

/// Result of a non-streaming chat completion.
class OpenAiChatCompletion {
  const OpenAiChatCompletion({
    required this.content,
    this.reasoning,
    this.toolCalls = const <OpenAiToolCall>[],
    this.finishReason,
  });

  final String content;
  final String? reasoning;

  /// Provider `finish_reason` (`stop` / `tool_calls` / `length` / …).
  /// `length` means the reply was cut off by the output-token limit.
  final String? finishReason;

  /// Tool calls the model asked for; [content] is usually empty when set.
  final List<OpenAiToolCall> toolCalls;

  bool get hasReasoning =>
      reasoning != null && reasoning!.trim().isNotEmpty;

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

/// One incremental chunk of a streamed chat completion.
class OpenAiChatDelta {
  const OpenAiChatDelta({
    this.content = '',
    this.reasoning = '',
    this.finishReason,
  });

  final String content;
  final String reasoning;

  /// Set on the final event when the provider named a reason.
  final String? finishReason;

  bool get isEmpty =>
      content.isEmpty && reasoning.isEmpty && finishReason == null;
}

/// Portable non-streaming OpenAI-compatible chat completions client.
///
/// No product/business types — callers supply endpoint fields directly.
class OpenAiChatClient {
  OpenAiChatClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 4096;

  Future<OpenAiChatCompletion> complete({
    required String baseUrl,
    required String model,
    required List<OpenAiChatMessage> messages,
    String apiKey = '',
    bool needsApiKey = true,
    String? fallbackBaseUrl,
    double temperature = defaultTemperature,
    int maxTokens = defaultMaxTokens,
    GenerationPreset? generation,
    /// OpenAI-style `reasoning_effort` (omit when null).
    String? reasoningEffort,
    /// OpenRouter-style nested `{ "effort": "low|medium|high" }`.
    Map<String, dynamic>? reasoning,
    /// Tools the model may call; omitted from the request when empty.
    List<OpenAiTool> tools = const <OpenAiTool>[],
    /// `auto` (default) / `none` / `required`; only sent with [tools].
    String? toolChoice,
  }) async {
    final request = _prepare(
      baseUrl: baseUrl,
      fallbackBaseUrl: fallbackBaseUrl,
      model: model,
      apiKey: apiKey,
      needsApiKey: needsApiKey,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      generation: generation,
      reasoningEffort: reasoningEffort,
      reasoning: reasoning,
      tools: tools,
      toolChoice: toolChoice,
    );

    late final http.Response response;
    try {
      response = await _client.post(
        request.uri,
        headers: request.headers,
        body: jsonEncode(request.body),
      );
    } catch (_) {
      throw OpenAiChatException('连不上服务，请检查地址或网络');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _extractErrorMessage(response.body);
      throw OpenAiChatException(
        detail.isEmpty ? '请求失败，请稍后重试' : detail,
      );
    }

    final decoded = _tryDecodeMap(response.body);
    if (decoded == null) {
      throw OpenAiChatException('返回内容无法识别');
    }
    return _completionFromMap(decoded);
  }

  /// Streams one completion as incremental deltas (`stream: true`).
  ///
  /// Providers that ignore streaming (plain JSON body) or reject
  /// `text/event-stream` still work: the whole reply is delivered as one
  /// content delta so callers never need a separate non-streaming path.
  Stream<OpenAiChatDelta> stream({
    required String baseUrl,
    required String model,
    required List<OpenAiChatMessage> messages,
    String apiKey = '',
    bool needsApiKey = true,
    String? fallbackBaseUrl,
    double temperature = defaultTemperature,
    int maxTokens = defaultMaxTokens,
    GenerationPreset? generation,
    String? reasoningEffort,
    Map<String, dynamic>? reasoning,
  }) async* {
    final prepared = _prepare(
      baseUrl: baseUrl,
      fallbackBaseUrl: fallbackBaseUrl,
      model: model,
      apiKey: apiKey,
      needsApiKey: needsApiKey,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      generation: generation,
      reasoningEffort: reasoningEffort,
      reasoning: reasoning,
      stream: true,
    );

    final request = http.Request('POST', prepared.uri)
      ..headers.addAll(prepared.headers)
      ..body = jsonEncode(prepared.body);
    request.headers['Accept'] = 'text/event-stream';

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (_) {
      throw OpenAiChatException('连不上服务，请检查地址或网络');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = await response.stream.bytesToString();
      final detail = _extractErrorMessage(raw);
      throw OpenAiChatException(
        detail.isEmpty ? '请求失败，请稍后重试' : detail,
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('text/event-stream')) {
      // Provider answered in one piece; keep the caller's stream shape.
      final raw = await response.stream.bytesToString();
      final decoded = _tryDecodeMap(raw);
      if (decoded == null) {
        throw OpenAiChatException('返回内容无法识别');
      }
      final completion = _completionFromMap(decoded);
      if (completion.hasReasoning) {
        yield OpenAiChatDelta(reasoning: completion.reasoning!);
      }
      yield OpenAiChatDelta(
        content: completion.content,
        finishReason: completion.finishReason,
      );
      return;
    }

    var content = StringBuffer();
    var reasoningText = StringBuffer();
    String? finishReason;
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty) continue;
      if (payload == '[DONE]') break;
      final map = _tryDecodeMap(payload);
      if (map == null) continue;
      final choices = map['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final first = choices.first;
      if (first is! Map) continue;
      final finishRaw = first['finish_reason'];
      if (finishRaw is String && finishRaw.isNotEmpty) {
        finishReason = finishRaw;
      }
      final delta = first['delta'];
      if (delta is! Map) continue;
      final rawContent = delta['content'];
      final deltaContent = rawContent is String ? rawContent : '';
      // Deltas must keep their own spacing — trim only for the emptiness test.
      final deltaReasoning = _readRawReasoningField(delta);
      if (deltaContent.isEmpty && deltaReasoning.isEmpty) continue;
      content.write(deltaContent);
      reasoningText.write(deltaReasoning);
      yield OpenAiChatDelta(
        content: deltaContent,
        reasoning: deltaReasoning,
      );
    }

    if (content.toString().trim().isEmpty) {
      throw _emptyReply(finishReason, reasoningText.toString());
    }
    yield OpenAiChatDelta(finishReason: finishReason);
  }

  /// Validates and builds the request shared by [complete] and [stream].
  ({
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  }) _prepare({
    required String baseUrl,
    required String model,
    required List<OpenAiChatMessage> messages,
    String apiKey = '',
    bool needsApiKey = true,
    String? fallbackBaseUrl,
    double temperature = defaultTemperature,
    int maxTokens = defaultMaxTokens,
    GenerationPreset? generation,
    String? reasoningEffort,
    Map<String, dynamic>? reasoning,
    List<OpenAiTool> tools = const <OpenAiTool>[],
    String? toolChoice,
    bool stream = false,
  }) {
    final base = normalizeOpenAiBaseUrl(
      baseUrl.trim().isEmpty ? (fallbackBaseUrl ?? '') : baseUrl,
    );
    if (base.isEmpty) {
      throw OpenAiChatException('请先填写服务地址');
    }
    if (model.trim().isEmpty) {
      throw OpenAiChatException('请先选择模型');
    }
    if (needsApiKey && apiKey.trim().isEmpty) {
      throw OpenAiChatException('请先填写密钥');
    }
    if (messages.isEmpty) {
      throw OpenAiChatException('没有可发送的内容');
    }

    final uri = Uri.parse('$base/chat/completions');
    final body = <String, dynamic>{
      'model': model.trim(),
      'messages': messages.map((m) => m.toJson()).toList(growable: false),
      'temperature': generation?.temperature ?? temperature,
      'max_tokens': generation?.maxTokens ?? maxTokens,
    };
    if (stream) {
      body['stream'] = true;
    }
    if (generation != null) {
      body['top_p'] = generation.topP;
      body['frequency_penalty'] = generation.frequencyPenalty;
      body['presence_penalty'] = generation.presencePenalty;
      if (generation.stopSequences.isNotEmpty) {
        body['stop'] = generation.stopSequences;
      }
      if (generation.seed >= 0) {
        body['seed'] = generation.seed;
      }
    }
    if (reasoning != null) {
      body['reasoning'] = reasoning;
    } else if (reasoningEffort != null && reasoningEffort.trim().isNotEmpty) {
      body['reasoning_effort'] = reasoningEffort.trim();
    }
    if (tools.isNotEmpty) {
      body['tools'] =
          tools.map((t) => t.toJson()).toList(growable: false);
      body['tool_choice'] = (toolChoice ?? '').trim().isEmpty
          ? 'auto'
          : toolChoice!.trim();
    }

    final headers = <String, String>{
      'Accept': stream ? 'text/event-stream' : 'application/json',
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${apiKey.trim()}',
    };

    return (uri: uri, headers: headers, body: body);
  }

  /// Decodes a non-streamed completion body.
  static OpenAiChatCompletion _completionFromMap(
    Map<String, dynamic> decoded,
  ) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw OpenAiChatException('模型没有返回可用内容');
    }
    final first = choices.first;
    if (first is! Map) {
      throw OpenAiChatException('模型没有返回可用内容');
    }
    final message = first['message'];
    if (message is! Map) {
      throw OpenAiChatException('模型没有返回可用内容');
    }
    final finishRaw = first['finish_reason'];
    final finishReason = finishRaw is String ? finishRaw : null;
    final rawContent = message['content'];
    var content = rawContent is String ? rawContent : '';
    final toolCalls = _readToolCalls(message);
    var reasoningText = _readReasoningField(message);
    // Tool-call replies legitimately carry no text; only treat "neither text
    // nor tools" as an empty response.
    if (content.trim().isEmpty && toolCalls.isEmpty) {
      throw _emptyReply(finishReason, reasoningText);
    }
    if (content.trim().isNotEmpty &&
        (reasoningText == null || reasoningText.isEmpty)) {
      final extracted = ThinkTagParser.extract(content);
      content = extracted.$1;
      reasoningText = extracted.$2;
    }
    if (content.trim().isEmpty && toolCalls.isEmpty) {
      throw _emptyReply(finishReason, reasoningText);
    }
    return OpenAiChatCompletion(
      content: content,
      toolCalls: toolCalls,
      finishReason: finishReason,
      reasoning: reasoningText?.trim().isEmpty ?? true
          ? null
          : reasoningText!.trim(),
    );
  }

  /// Names what actually went wrong instead of one opaque「没有内容」.
  static OpenAiChatException _emptyReply(
    String? finishReason,
    String? reasoningText,
  ) {
    if (finishReason == 'length') {
      return OpenAiChatException(
        '这次的输出触到长度上限被截断了，少生成一点再试',
        code: OpenAiChatException.truncated,
      );
    }
    final hasReasoning = reasoningText != null && reasoningText.trim().isNotEmpty;
    if (hasReasoning) {
      return OpenAiChatException(
        '模型只写了思考，没给出正文，稍后再试',
        code: OpenAiChatException.thinkingOnly,
      );
    }
    return OpenAiChatException(
      '模型没有返回可用内容',
      code: OpenAiChatException.empty,
    );
  }

  /// Reads OpenAI-style `message.tool_calls`; empty when absent or unusable.
  static List<OpenAiToolCall> _readToolCalls(Map message) {
    final raw = message['tool_calls'];
    if (raw is! List) return const <OpenAiToolCall>[];
    final calls = <OpenAiToolCall>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final call = OpenAiToolCall.fromJson(Map<String, dynamic>.from(item));
      if (call.name.isEmpty) continue;
      calls.add(
        call.id.isEmpty
            ? OpenAiToolCall(
                id: 'call_${calls.length}',
                name: call.name,
                arguments: call.arguments,
              )
            : call,
      );
    }
    return calls;
  }

  /// DeepSeek / o-series style fields on `message`.
  static String? _readReasoningField(Map message) {
    for (final key in const [
      'reasoning_content',
      'reasoning',
      'thought',
    ]) {
      final value = message[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  /// Same fields as [_readReasoningField] but keeps the delta's own spacing.
  static String _readRawReasoningField(Map delta) {
    for (final key in const [
      'reasoning_content',
      'reasoning',
      'thought',
    ]) {
      final value = delta[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return '';
  }

  static Map<String, dynamic>? _tryDecodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  /// Reads OpenAI-style `{ "error": { "message": "..." } }` when present.
  static String _extractErrorMessage(String body) {
    final map = _tryDecodeMap(body);
    if (map == null) return '';
    final error = map['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return '';
  }
}

class OpenAiChatException implements Exception {
  OpenAiChatException(this.message, {this.code});

  final String message;

  /// Machine-readable cause for replies that carried no usable content
  /// (`truncated` / `thinking_only` / `empty`); null for request errors.
  final String? code;

  /// `finish_reason: length` — the reply was cut off by the output limit.
  static const String truncated = 'truncated';

  /// The model spent its whole budget on reasoning and left no answer.
  static const String thinkingOnly = 'thinking_only';

  /// Neither text nor tool calls came back.
  static const String empty = 'empty';

  @override
  String toString() => message;
}
