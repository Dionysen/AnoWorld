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
    expect(settings.innerInsetRatio, AppDialogueChrome.defaultInnerInsetRatio);
    expect(settings.outerInsetRatio, AppDialogueChrome.defaultOuterInsetRatio);
    expect(settings.controlSizeRatio, AppDialogueChrome.defaultControlSizeRatio);
    expect(
      settings.controlTopGapRatio,
      AppDialogueChrome.defaultControlTopGapRatio,
    );
    expect(
      settings.controlBottomGapRatio,
      AppDialogueChrome.defaultControlBottomGapRatio,
    );
    expect(settings.cornerRadius, AppDialogueChrome.defaultCornerRadius);
  });

  test('fromJson clamps out-of-range values', () {
    final settings = VnUiSettings.fromJson(<String, dynamic>{
      'lines': 99,
      'fontSize': 1,
      'opacity': 3,
      'textSpeed': 999,
      'cornerRadius': 99,
    });
    expect(settings.lines, AppDialogueChrome.maxLines);
    expect(settings.fontSize, AppDialogueChrome.minFontSize);
    expect(settings.opacity, AppDialogueChrome.maxOpacity);
    expect(settings.textSpeed, AppDialogueChrome.maxTextSpeed);
    expect(settings.cornerRadius, AppDialogueChrome.maxCornerRadius);
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
      cornerRadius: 20,
      innerInsetRatio: 0.6,
      outerInsetRatio: 0.4,
      controlSizeRatio: 1.2,
      controlTopGapRatio: 0.25,
      controlBottomGapRatio: 0.35,
    );
    final restored = VnUiSettings.fromJson(original.toJson());
    expect(restored, original);
    expect(restored.followsTheme, isFalse);
    expect(restored.textFollowsTheme, isFalse);
  });

  test('resolved fills missing inset fields after legacy load', () {
    const legacy = VnUiSettings(fontSize: 18, lines: 3);
    final fixed = VnUiSettings.resolved(legacy);
    expect(fixed.innerInsetRatio, AppDialogueChrome.defaultInnerInsetRatio);
    expect(fixed.outerInsetRatio, AppDialogueChrome.defaultOuterInsetRatio);
    expect(fixed.lines, 3);
    expect(fixed.fontSize, 18);
  });

  test('fromJson without inset keys uses defaults', () {
    final settings = VnUiSettings.fromJson(<String, dynamic>{
      'lines': 4,
      'fontSize': 16,
    });
    expect(settings.innerInsetRatio, AppDialogueChrome.defaultInnerInsetRatio);
    expect(settings.outerInsetRatio, AppDialogueChrome.defaultOuterInsetRatio);
    expect(settings.controlSizeRatio, AppDialogueChrome.defaultControlSizeRatio);
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
