import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('AppBusyIndicator paints a progress ring', (tester) async {
    await tester.pumpWidget(
      testLocalized(home: const Scaffold(body: AppBusyIndicator())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppBusyIndicator exposes a semantic label', (tester) async {
    await tester.pumpWidget(
      testLocalized(
        home: const Scaffold(
          body: AppBusyIndicator(semanticLabel: '生成中'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('生成中'), findsOneWidget);
  });
}
