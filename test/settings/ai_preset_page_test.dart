import 'package:anoworld/settings/ai_preset_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('preset page exposes picker, sampling and prompts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(testScoped(home: const AiPresetPage()));
    await tester.pumpAndSettle();

    expect(find.text('预设'), findsWidgets);
    expect(find.text('采样'), findsOneWidget);
    expect(find.text('预设提示词'), findsOneWidget);
    expect(find.text('温度'), findsOneWidget);
    expect(find.text('高级采样'), findsOneWidget);

    await tester.tap(find.text('高级采样'));
    await tester.pumpAndSettle();
    expect(find.text('Top K'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('尚未选用'));
    await tester.pumpAndSettle();
    expect(find.text('选择预设'), findsOneWidget);
    expect(find.text('内置'), findsOneWidget);
    await tester.tapAt(const Offset(8, 200));
    await tester.pumpAndSettle();
  });
}
