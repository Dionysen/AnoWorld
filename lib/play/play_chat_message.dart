import 'package:anoworld/domain/chat/tavern_chat_message.dart';

export 'package:anoworld/domain/chat/tavern_chat_message.dart';

/// UI row for tavern chat (user right / assistant left).
class PlayChatMessage {
  const PlayChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.avatarLabel,
    this.reasoning,
    this.streaming = false,
  });

  final String id;
  final String text;
  final bool isUser;
  final String? avatarLabel;
  final String? reasoning;

  /// Assistant turn still arriving; suppresses the typing bubble.
  final bool streaming;

  factory PlayChatMessage.fromTavern(
    TavernChatMessage message, {
    required String userLabel,
    required String assistantLabel,
    bool streaming = false,
  }) {
    final isUser = message.role == TavernChatRole.user;
    return PlayChatMessage(
      id: message.id,
      text: message.content,
      isUser: isUser,
      avatarLabel: isUser ? userLabel : assistantLabel,
      reasoning: isUser ? null : message.reasoning,
      streaming: streaming,
    );
  }
}
