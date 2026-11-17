import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match chat chrome', () {
    const settings = ChatUiSettings();
    expect(settings.lineHeight, AppChatChrome.defaultLineHeight);
    expect(settings.paragraphSpacing, AppChatChrome.defaultParagraphSpacing);
  });

  test('fromJson clamps out-of-range values', () {
    final settings = ChatUiSettings.fromJson(<String, dynamic>{
      'lineHeight': 9,
      'paragraphSpacing': -3,
    });
    expect(settings.lineHeight, AppChatChrome.maxLineHeight);
    expect(settings.paragraphSpacing, AppChatChrome.minParagraphSpacing);
  });

  test('round-trips json', () {
    const original = ChatUiSettings(lineHeight: 1.6, paragraphSpacing: 12);
    final restored = ChatUiSettings.fromJson(original.toJson());
    expect(restored, original);
  });
}
