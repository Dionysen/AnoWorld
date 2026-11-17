import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/theme/app_chat_background.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';

/// Chat-only presentation prefs (not global appearance).
class ChatUiSettings {
  const ChatUiSettings({
    this.lineHeight = AppChatChrome.defaultLineHeight,
    this.paragraphSpacing = AppChatChrome.defaultParagraphSpacing,
    this.bubbleCornerRadius = AppChatChrome.bubbleCornerRadius,
    this.showCharacterAvatar = true,
    this.showUserAvatar = true,
    this.avatarAboveBubble = true,
    this.showReasoning = false,
    this.background = AppChatBackground.none,
  });

  final double lineHeight;
  final double paragraphSpacing;
  final double bubbleCornerRadius;
  final bool showCharacterAvatar;
  final bool showUserAvatar;
  final bool avatarAboveBubble;
  final bool showReasoning;
  final AppChatBackground background;

  ChatUiSettings copyWith({
    double? lineHeight,
    double? paragraphSpacing,
    double? bubbleCornerRadius,
    bool? showCharacterAvatar,
    bool? showUserAvatar,
    bool? avatarAboveBubble,
    bool? showReasoning,
    AppChatBackground? background,
  }) {
    return ChatUiSettings(
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      bubbleCornerRadius: bubbleCornerRadius ?? this.bubbleCornerRadius,
      showCharacterAvatar: showCharacterAvatar ?? this.showCharacterAvatar,
      showUserAvatar: showUserAvatar ?? this.showUserAvatar,
      avatarAboveBubble: avatarAboveBubble ?? this.avatarAboveBubble,
      showReasoning: showReasoning ?? this.showReasoning,
      background: background ?? this.background,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'bubbleCornerRadius': bubbleCornerRadius,
        'showCharacterAvatar': showCharacterAvatar,
        'showUserAvatar': showUserAvatar,
        'avatarAboveBubble': avatarAboveBubble,
        'showReasoning': showReasoning,
        'background': background.toJson(),
      };

  factory ChatUiSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChatUiSettings();
    return ChatUiSettings(
      lineHeight: _clamp(
        (json.optionalNum('lineHeight') ?? AppChatChrome.defaultLineHeight)
            .toDouble(),
        AppChatChrome.minLineHeight,
        AppChatChrome.maxLineHeight,
      ),
      paragraphSpacing: _clamp(
        (json.optionalNum('paragraphSpacing') ??
                AppChatChrome.defaultParagraphSpacing)
            .toDouble(),
        AppChatChrome.minParagraphSpacing,
        AppChatChrome.maxParagraphSpacing,
      ),
      bubbleCornerRadius: _clamp(
        (json.optionalNum('bubbleCornerRadius') ??
                AppChatChrome.bubbleCornerRadius)
            .toDouble(),
        AppChatChrome.minBubbleCornerRadius,
        AppChatChrome.maxBubbleCornerRadius,
      ),
      showCharacterAvatar: json.optionalBool('showCharacterAvatar') ?? true,
      showUserAvatar: json.optionalBool('showUserAvatar') ?? true,
      avatarAboveBubble: json.optionalBool('avatarAboveBubble') ?? true,
      showReasoning: json.optionalBool('showReasoning') ?? false,
      background: AppChatBackground.fromJson(json.optionalMap('background')),
    );
  }

  static double _clamp(double value, double min, double max) =>
      value.clamp(min, max);

  @override
  bool operator ==(Object other) {
    return other is ChatUiSettings &&
        other.lineHeight == lineHeight &&
        other.paragraphSpacing == paragraphSpacing &&
        other.bubbleCornerRadius == bubbleCornerRadius &&
        other.showCharacterAvatar == showCharacterAvatar &&
        other.showUserAvatar == showUserAvatar &&
        other.avatarAboveBubble == avatarAboveBubble &&
        other.showReasoning == showReasoning &&
        other.background == background;
  }

  @override
  int get hashCode => Object.hash(
        lineHeight,
        paragraphSpacing,
        bubbleCornerRadius,
        showCharacterAvatar,
        showUserAvatar,
        avatarAboveBubble,
        showReasoning,
        background,
      );
}
