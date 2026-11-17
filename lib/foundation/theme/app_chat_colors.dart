import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Chat palette (NativeTavern `AppChatColors` / ThemeTokens chat slots).
@immutable
class AppChatColors extends ThemeExtension<AppChatColors> {
  const AppChatColors({
    required this.background,
    required this.characterBubble,
    required this.userBubble,
    required this.chatText,
    required this.dialogueText,
  });

  final Color background;
  final Color characterBubble;
  final Color userBubble;
  final Color chatText;
  final Color dialogueText;

  static const fallback = AppChatColors(
    background: Color(0xFF1F1F1F),
    characterBubble: Color(0xFF313131),
    userBubble: Color(0xFF2A3340),
    chatText: Color(0xFFCCCCCC),
    dialogueText: Color(0xFFE09A5A),
  );

  factory AppChatColors.fromThemeTokens(ThemeTokens tokens) => AppChatColors(
        background: Color(tokens.chatBackground),
        characterBubble: Color(tokens.characterBubble),
        userBubble: Color(tokens.userBubble),
        chatText: Color(tokens.chatText),
        dialogueText: Color(tokens.dialogueText),
      );

  static AppChatColors of(BuildContext context) {
    return Theme.of(context).extension<AppChatColors>() ?? fallback;
  }

  @override
  AppChatColors copyWith({
    Color? background,
    Color? characterBubble,
    Color? userBubble,
    Color? chatText,
    Color? dialogueText,
  }) {
    return AppChatColors(
      background: background ?? this.background,
      characterBubble: characterBubble ?? this.characterBubble,
      userBubble: userBubble ?? this.userBubble,
      chatText: chatText ?? this.chatText,
      dialogueText: dialogueText ?? this.dialogueText,
    );
  }

  @override
  AppChatColors lerp(ThemeExtension<AppChatColors>? other, double t) {
    if (other is! AppChatColors) return this;
    return AppChatColors(
      background: Color.lerp(background, other.background, t)!,
      characterBubble:
          Color.lerp(characterBubble, other.characterBubble, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      chatText: Color.lerp(chatText, other.chatText, t)!,
      dialogueText: Color.lerp(dialogueText, other.dialogueText, t)!,
    );
  }
}
