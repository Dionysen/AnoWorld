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
  });

  final String id;
  final TavernChatRole role;
  final String content;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'role': role.wireName,
        'content': content,
      };

  factory TavernChatMessage.fromJson(Map<String, dynamic> json) {
    return TavernChatMessage(
      id: json.requireString('id'),
      role: TavernChatRoleCodec.parse(json.optionalString('role')),
      content: json.requireString('content'),
    );
  }

  TavernChatMessage copyWith({String? content}) {
    return TavernChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
    );
  }
}
