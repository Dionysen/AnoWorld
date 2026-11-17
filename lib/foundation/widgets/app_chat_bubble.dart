import 'package:flutter/material.dart';

import '../theme/app_chat_chrome.dart';
import '../theme/app_theme.dart';
import 'app_chat_dialogue_text.dart';
import 'app_shaped_avatar.dart';

/// Chat message bubble (NativeTavern bubble layout: avatar above, sharp outer corner).
class AppChatBubble extends StatelessWidget {
  const AppChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.avatarLabel,
    this.showAvatar = true,
    this.isTyping = false,
    this.onLongPress,
  });

  final String text;
  final bool isUser;

  /// Single glyph / initial drawn inside the avatar circle.
  final String? avatarLabel;
  final bool showAvatar;
  final bool isTyping;
  final VoidCallback? onLongPress;

  static const double _avatarRadius = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cross = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubble = DecoratedBox(
      decoration: AppChatChrome.messageBubbleDecoration(
        context,
        isUser: isUser,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: isTyping
            ? const _AppChatTypingDots()
            : AppChatDialogueText(text: text, isUser: isUser),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: cross,
        children: [
          if (showAvatar) ...[
            AppShapedAvatar(
              width: _avatarRadius * 2,
              height: _avatarRadius * 2,
              backgroundColor: isUser
                  ? AppChatChrome.userAvatarFill(scheme)
                  : scheme.primary.withValues(alpha: 0.18),
              child: isUser
                  ? Icon(
                      Icons.person,
                      size: 18,
                      color: scheme.primary,
                    )
                  : Text(
                      _initial(avatarLabel),
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
          ],
          GestureDetector(
            onLongPress: onLongPress,
            child: SizedBox(width: double.infinity, child: Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: bubble,
            )),
          ),
        ],
      ),
    );
  }

  static String _initial(String? label) {
    final t = (label ?? '').trim();
    if (t.isEmpty) return '·';
    return String.fromCharCodes(t.runes.take(1));
  }
}

class _AppChatTypingDots extends StatefulWidget {
  const _AppChatTypingDots();

  @override
  State<_AppChatTypingDots> createState() => _AppChatTypingDotsState();
}

class _AppChatTypingDotsState extends State<_AppChatTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppChatChrome.bubbleTextColor(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppTheme.spaceXs),
              Opacity(
                opacity: _dotOpacity(i),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double _dotOpacity(int index) {
    final t = (_controller.value + index / 3) % 1.0;
    return 0.35 + 0.65 * (1 - (t - 0.5).abs() * 2);
  }
}
