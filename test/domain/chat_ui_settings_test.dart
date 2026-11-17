import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/foundation/theme/app_chat_background.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match chat chrome', () {
    const settings = ChatUiSettings();
    expect(settings.lineHeight, AppChatChrome.defaultLineHeight);
    expect(settings.paragraphSpacing, AppChatChrome.defaultParagraphSpacing);
    expect(settings.bubbleCornerRadius, AppChatChrome.bubbleCornerRadius);
    expect(settings.showCharacterAvatar, isTrue);
    expect(settings.showUserAvatar, isTrue);
    expect(settings.avatarAboveBubble, isTrue);
    expect(settings.showReasoning, isFalse);
    expect(settings.background, AppChatBackground.none);
  });

  test('fromJson clamps out-of-range values', () {
    final settings = ChatUiSettings.fromJson(<String, dynamic>{
      'lineHeight': 9,
      'paragraphSpacing': -3,
      'bubbleCornerRadius': 99,
    });
    expect(settings.lineHeight, AppChatChrome.maxLineHeight);
    expect(settings.paragraphSpacing, AppChatChrome.minParagraphSpacing);
    expect(settings.bubbleCornerRadius, AppChatChrome.maxBubbleCornerRadius);
  });

  test('round-trips json', () {
    final original = ChatUiSettings(
      lineHeight: 1.6,
      paragraphSpacing: 12,
      bubbleCornerRadius: 18,
      showCharacterAvatar: false,
      showUserAvatar: true,
      avatarAboveBubble: false,
      showReasoning: true,
      background: AppChatBackground.gradientPresets.first,
    );
    final restored = ChatUiSettings.fromJson(original.toJson());
    expect(restored, original);
  });
}
