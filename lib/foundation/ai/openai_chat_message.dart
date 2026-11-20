import 'dart:convert';

/// One function tool the model may call.
class OpenAiTool {
  const OpenAiTool({
    required this.name,
    required this.parameters,
    this.description = '',
  });

  final String name;
  final String description;

  /// JSON Schema object describing the arguments.
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'function',
        'function': <String, dynamic>{
          'name': name,
          if (description.trim().isNotEmpty) 'description': description.trim(),
          'parameters': parameters,
        },
      };
}

/// One tool call requested by the model.
class OpenAiToolCall {
  const OpenAiToolCall({
    required this.id,
    required this.name,
    this.arguments = '',
  });

  final String id;
  final String name;

  /// Raw JSON arguments string, kept verbatim so callers can decode (and
  /// recover from) whatever the model produced.
  final String arguments;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': 'function',
        'function': <String, dynamic>{'name': name, 'arguments': arguments},
      };

  factory OpenAiToolCall.fromJson(Map<String, dynamic> json) {
    final function = json['function'];
    final rawArgs = function is Map ? function['arguments'] : null;
    return OpenAiToolCall(
      id: '${json['id'] ?? ''}'.trim(),
      name: function is Map ? '${function['name'] ?? ''}'.trim() : '',
      arguments: switch (rawArgs) {
        String value => value,
        Map value => jsonEncode(value),
        List value => jsonEncode(value),
        _ => '',
      },
    );
  }
}

/// One chat message for OpenAI-compatible `/chat/completions`.
///
/// `role: 'tool'` carries a [toolCallId] and the tool output as [content];
/// assistant turns that ask for tools carry [toolCalls] and may leave
/// [content] empty.
class OpenAiChatMessage {
  const OpenAiChatMessage({
    required this.role,
    this.content = '',
    this.toolCalls = const <OpenAiToolCall>[],
    this.toolCallId,
    this.name,
  });

  final String role;
  final String content;
  final List<OpenAiToolCall> toolCalls;
  final String? toolCallId;

  /// Optional `name`; some providers echo the tool name on tool replies.
  final String? name;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role,
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (name != null) 'name': name,
        if (toolCalls.isNotEmpty)
          'tool_calls': toolCalls.map((c) => c.toJson()).toList(growable: false),
        'content': content,
      };
}
