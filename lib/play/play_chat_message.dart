/// Display row for play chat (NativeTavern-style bubble list).
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
}

/// Speaker id for player lines injected from the chat composer.
const String kPlayUserSpeakerId = '__user__';
