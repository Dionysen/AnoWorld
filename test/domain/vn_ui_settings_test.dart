import 'package:anoworld/domain/settings/vn_ui_settings.dart';
import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match dialogue chrome', () {
    const settings = VnUiSettings();
    expect(settings.lines, AppDialogueChrome.defaultLines);
    expect(settings.fontSize, AppDialogueChrome.defaultFontSize);
    expect(settings.opacity, AppDialogueChrome.defaultOpacity);
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
    });
    expect(settings.lines, AppDialogueChrome.maxLines);
    expect(settings.fontSize, AppDialogueChrome.minFontSize);
    expect(settings.opacity, AppDialogueChrome.maxOpacity);
  });

  test('round-trips json', () {
    const original = VnUiSettings(
      lines: 5,
      fontSize: 20,
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
