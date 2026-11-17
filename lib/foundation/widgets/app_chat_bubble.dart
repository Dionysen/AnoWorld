import 'package:flutter/material.dart';

import '../theme/app_chat_chrome.dart';
import '../theme/app_theme.dart';
import 'app_chat_dialogue_text.dart';
import 'app_shaped_avatar.dart';

/// Chat bubble alignment / chrome role.
enum AppChatBubbleRole {
  /// Left-aligned character bubble.
  character,

  /// Right-aligned user bubble.
  user,

  /// Centered narration (no side tip, no avatar).
  narration,
}

/// Chat message bubble (NativeTavern-inspired chrome).
class AppChatBubble extends StatelessWidget {
  const AppChatBubble({
    super.key,
    required this.text,
    this.role = AppChatBubbleRole.character,
    this.avatarLabel,
    this.showAvatar = true,
    this.isTyping = false,
    this.onLongPress,
    this.lineHeight = AppChatChrome.defaultLineHeight,
    this.paragraphSpacing = AppChatChrome.defaultParagraphSpacing,
  });

  final String text;
  final AppChatBubbleRole role;

  /// Display name (shown inside the bubble) and avatar initial source.
  final String? avatarLabel;
  final bool showAvatar;
  final bool isTyping;
  final VoidCallback? onLongPress;
  final double lineHeight;
  final double paragraphSpacing;

  static const double _avatarRadius = 16;
  static const double _narrationMaxWidth = 420;

  bool get _isUser => role == AppChatBubbleRole.user;
  bool get _isNarration => role == AppChatBubbleRole.narration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = avatarLabel?.trim();
    final bubbleBody = isTyping
        ? const _AppChatTypingDots()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (name != null && name.isNotEmpty && !_isNarration) ...[
                Text(
                  name,
                  style: AppChatChrome.messageInputStyle(context).copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: (AppChatChrome.messageFontSize(context) - 1)
                        .clamp(11, 18),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
              ],
              AppChatDialogueText(
                text: text,
                isUser: _isUser,
                lineHeight: lineHeight,
                paragraphSpacing: paragraphSpacing,
              ),
            ],
          );
    final bubble = DecoratedBox(
      decoration: AppChatChrome.messageBubbleDecoration(
        context,
        isUser: _isUser,
        narration: _isNarration,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: bubbleBody,
      ),
    );

    if (_isNarration) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _narrationMaxWidth),
            child: GestureDetector(
              onLongPress: onLongPress,
              child: bubble,
            ),
          ),
        ),
      );
    }

    final cross =
        _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: cross,
        children: [
          if (showAvatar) ...[
            AppShapedAvatar(
              width: _avatarRadius * 2,
              height: _avatarRadius * 2,
              backgroundColor: _isUser
                  ? AppChatChrome.userAvatarFill(scheme)
                  : scheme.primary.withValues(alpha: 0.18),
              child: _isUser
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
            child: SizedBox(
              width: double.infinity,
              child: Align(
                alignment:
                    _isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: bubble,
              ),
            ),
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
