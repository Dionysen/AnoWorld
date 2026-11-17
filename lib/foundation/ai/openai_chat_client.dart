import 'dart:convert';

import 'package:anoworld/foundation/ai/openai_base_url.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:http/http.dart' as http;

/// Portable non-streaming OpenAI-compatible chat completions client.
///
/// No product/business types — callers supply endpoint fields directly.
class OpenAiChatClient {
  OpenAiChatClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 4096;

  Future<String> complete({
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
  }) async {
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

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${apiKey.trim()}',
    };

    late final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
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
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw OpenAiChatException('模型没有返回可用内容');
    }
    return content;
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
  OpenAiChatException(this.message);

  final String message;

  @override
  String toString() => message;
}
