import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';

/// Chat-only presentation prefs (not global appearance).
class ChatUiSettings {
  const ChatUiSettings({
    this.lineHeight = AppChatChrome.defaultLineHeight,
    this.paragraphSpacing = AppChatChrome.defaultParagraphSpacing,
  });

  final double lineHeight;
  final double paragraphSpacing;

  ChatUiSettings copyWith({
    double? lineHeight,
    double? paragraphSpacing,
  }) {
    return ChatUiSettings(
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
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
    );
  }

  static double _clamp(double value, double min, double max) =>
      value.clamp(min, max);

  @override
  bool operator ==(Object other) {
    return other is ChatUiSettings &&
        other.lineHeight == lineHeight &&
        other.paragraphSpacing == paragraphSpacing;
  }

  @override
  int get hashCode => Object.hash(lineHeight, paragraphSpacing);
}
