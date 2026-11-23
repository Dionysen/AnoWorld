import 'package:anoworld/domain/settings/vn_ui_settings.dart';
import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match dialogue chrome', () {
    const settings = VnUiSettings();
    expect(settings.lines, AppDialogueChrome.defaultLines);
    expect(settings.fontSize, AppDialogueChrome.defaultFontSize);
    expect(settings.opacity, AppDialogueChrome.defaultOpacity);
    expect(settings.textSpeed, AppDialogueChrome.defaultTextSpeed);
    expect(settings.typewriterEnabled, isTrue);
    expect(settings.backgroundHex, isEmpty);
    expect(settings.followsTheme, isTrue);
    expect(settings.textHex, isEmpty);
    expect(settings.textFollowsTheme, isTrue);
  });

  test('fromJson clamps out-of-range values', () {
    final settings = VnUiSettings.fromJson(<String, dynamic>{
      'lines': 99,
      'fontSize': 1,
      'opacity': 3,
      'textSpeed': 999,
    });
    expect(settings.lines, AppDialogueChrome.maxLines);
    expect(settings.fontSize, AppDialogueChrome.minFontSize);
    expect(settings.opacity, AppDialogueChrome.maxOpacity);
    expect(settings.textSpeed, AppDialogueChrome.maxTextSpeed);
  });

  test('zero text speed means instant reveal', () {
    final settings = const VnUiSettings().copyWith(textSpeed: 0);
    expect(settings.typewriterEnabled, isFalse);
    expect(VnUiSettings.fromJson(settings.toJson()).textSpeed, 0);
  });

  test('round-trips json', () {
    const original = VnUiSettings(
      lines: 5,
      fontSize: 20,
      textSpeed: 42,
      backgroundHex: '#10131B',
      textHex: '#F2F4F8',
      opacity: 0.5,
    );
    final restored = VnUiSettings.fromJson(original.toJson());
    expect(restored, original);
    expect(restored.followsTheme, isFalse);
    expect(restored.textFollowsTheme, isFalse);
  });

  test('each colour follows the theme on its own', () {
    const settings = VnUiSettings(textHex: '#FFFFFF');
    expect(settings.followsTheme, isTrue);
    expect(settings.textFollowsTheme, isFalse);

    final cleared = settings.copyWith(textHex: '');
    expect(cleared.textFollowsTheme, isTrue);
    expect(cleared.backgroundHex, isEmpty);
  });
}
