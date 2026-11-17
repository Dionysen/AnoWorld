import 'package:anoworld/domain/chat/tavern_chat_message.dart';

export 'package:anoworld/domain/chat/tavern_chat_message.dart';

/// UI row for tavern chat (user right / assistant left).
class PlayChatMessage {
  const PlayChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.avatarLabel,
  });

  final String id;
  final String text;
  final bool isUser;
  final String? avatarLabel;

  factory PlayChatMessage.fromTavern(
    TavernChatMessage message, {
    String? userLabel,
    String? assistantLabel,
  }) {
    final isUser = message.role == TavernChatRole.user;
    return PlayChatMessage(
      id: message.id,
      text: message.content,
      isUser: isUser,
      avatarLabel: isUser ? (userLabel ?? '我') : (assistantLabel ?? '角色'),
    );
  }
}
