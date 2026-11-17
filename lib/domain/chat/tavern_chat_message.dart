import 'package:anoworld/domain/models/json_map.dart';

enum TavernChatRole { user, assistant }

extension TavernChatRoleCodec on TavernChatRole {
  String get wireName => name;

  static TavernChatRole parse(String? raw) {
    if (raw == 'user') return TavernChatRole.user;
    return TavernChatRole.assistant;
  }
}

/// One tavern-style chat turn (NT ChatMessage subset).
class TavernChatMessage {
  const TavernChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.reasoning,
  });

  final String id;
  final TavernChatRole role;
  final String content;

  /// Optional chain-of-thought / reasoning text (assistant only).
  final String? reasoning;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'role': role.wireName,
        'content': content,
        if (reasoning != null && reasoning!.trim().isNotEmpty)
          'reasoning': reasoning,
      };

  factory TavernChatMessage.fromJson(Map<String, dynamic> json) {
    return TavernChatMessage(
      id: json.requireString('id'),
      role: TavernChatRoleCodec.parse(json.optionalString('role')),
      content: json.requireString('content'),
      reasoning: json.optionalString('reasoning'),
    );
  }

  TavernChatMessage copyWith({
    String? content,
    String? reasoning,
  }) {
    return TavernChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
    );
  }
}
