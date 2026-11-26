import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insets scale with font size and ratio', () {
    const fontSize = 20.0;
    const inner = 0.5;
    const outer = 0.75;
    expect(AppDialogueChrome.insetPixels(fontSize, inner), 10);
    expect(
      AppDialogueChrome.paddingFor(fontSize, innerInsetRatio: inner),
      const EdgeInsets.all(10),
    );
    expect(
      AppDialogueChrome.stageMarginFor(fontSize, outerInsetRatio: outer),
      15,
    );
    expect(
      AppDialogueChrome.panelHeight(
        lines: 4,
        fontSize: fontSize,
        innerInsetRatio: inner,
      ),
      AppDialogueChrome.headerHeight +
          AppDialogueChrome.bodyHeight(4, fontSize) +
          20,
    );
  });

  test('control diameter follows font size and ratio', () {
    expect(
      AppDialogueChrome.controlDiameter(16, 2),
      32,
    );
    expect(
      AppDialogueChrome.controlDiameter(20, 4),
      80,
    );
    expect(AppDialogueChrome.controlVerticalGap(16, 0.5), 8);
    expect(
      AppDialogueChrome.controlIconSize(32),
      closeTo(18, 0.01),
    );
  });

  test('sprite height is an absolute multiple of font size', () {
    expect(
      AppDialogueChrome.spriteHeightFor(fontSize: 14, maxHeight: 2000),
      14 * AppDialogueChrome.spriteHeightPerFontSize,
    );
    expect(
      AppDialogueChrome.spriteHeightFor(fontSize: 20, maxHeight: 2000),
      20 * AppDialogueChrome.spriteHeightPerFontSize,
    );
    expect(
      AppDialogueChrome.spriteHeightFor(fontSize: 20, maxHeight: 100),
      100,
    );
  });
}