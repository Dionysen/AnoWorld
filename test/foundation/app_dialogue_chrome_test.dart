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
}