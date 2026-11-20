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
}
