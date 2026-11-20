import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('labeled segments render text and report taps', (tester) async {
    var value = 'a';
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 320,
                child: AppSegmented<String>(
                  value: value,
                  options: const [
                    AppSegmentOption(value: 'a', label: '甲'),
                    AppSegmentOption(value: 'b', label: '乙'),
                  ],
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('甲'), findsOneWidget);
    await tester.tap(find.text('乙'));
    await tester.pumpAndSettle();
    expect(value, 'b');
  });

  testWidgets('icon segments draw only icons and keep labels as tooltips', (
    tester,
  ) async {
    var value = 'a';
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: AppIconSegmented<String>(
                value: value,
                options: const [
                  AppSegmentOption(
                    value: 'a',
                    label: '甲',
                    icon: Icons.public_outlined,
                  ),
                  AppSegmentOption(
                    value: 'b',
                    label: '乙',
                    icon: Icons.groups_outlined,
                  ),
                ],
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );

    // No visible text: the group stays as wide as its squares.
    expect(find.text('甲'), findsNothing);
    expect(find.byIcon(Icons.public_outlined), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppIconSegmented<String>)).width,
      AppIconSegmented.segmentSize * 2,
    );

    expect(find.byTooltip('甲'), findsOneWidget);
    await tester.tap(find.byTooltip('乙'));
    await tester.pumpAndSettle();
    expect(value, 'b');
  });
}
