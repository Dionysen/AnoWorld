import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insets scale with font size', () {
    const fontSize = 20.0;
    expect(AppDialogueChrome.insetForFontSize(fontSize), fontSize * 0.5);
    expect(
      AppDialogueChrome.paddingFor(fontSize),
      const EdgeInsets.all(10),
    );
    expect(AppDialogueChrome.stageMarginFor(fontSize), 10);
    expect(
      AppDialogueChrome.panelHeight(lines: 4, fontSize: fontSize),
      AppDialogueChrome.headerHeight +
          AppDialogueChrome.bodyHeight(4, fontSize) +
          20,
    );
  });
}