import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';
import 'package:anoworld/foundation/widgets/app_dialogue_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Widget _panel({
  required Widget child,
  int lines = 3,
  double fontSize = 16,
  Widget? header,
  Widget? trailing,
}) {
  return testLocalized(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: AppDialoguePanel(
            lines: lines,
            fontSize: fontSize,
            header: header,
            trailing: trailing,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('height is fixed by lines and font size, not content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _panel(child: const Text('短句。'), header: const Text('姚江雪')),
    );
    final short = tester.getSize(find.byType(AppDialoguePanel));

    await tester.pumpWidget(_panel(child: Text('很长的一段旁白' * 30), header: null));
    final long = tester.getSize(find.byType(AppDialoguePanel));

    final expected = AppDialogueChrome.panelHeight(lines: 3, fontSize: 16);
    expect(short.height, expected);
    expect(long.height, expected);
    expect(short.width, 300);
  });

  testWidgets('keeps the speaker row and page counter slots', (tester) async {
    await tester.pumpWidget(
      _panel(
        child: const Text('第二页。'),
        header: const Text('姚江雪'),
        trailing: const Text('2/3'),
      ),
    );

    expect(find.text('姚江雪'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('第二页。'), findsOneWidget);
  });

  testWidgets('blurs the stage behind a translucent fill', (tester) async {
    await tester.pumpWidget(
      _panel(child: const Text('雨还在下。'), header: const Text('旁白')),
    );

    final backdrop = tester.widget<BackdropFilter>(
      find.descendant(
        of: find.byType(AppDialoguePanel),
        matching: find.byType(BackdropFilter),
      ),
    );
    expect(backdrop.filter, isNotNull);
    expect(find.byType(ClipRRect), findsWidgets);
  });
}
