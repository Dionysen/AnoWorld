import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/play/play_role_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  testWidgets('role sheet lists the cast and returns the tapped member', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      testScoped(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: AppButton(
                label: 'choose',
                onPressed: () async {
                  picked = await showPlayRoleSheet(context, project: sample);
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('choose'));
    await tester.pumpAndSettle();

    expect(find.text('你扮演谁'), findsOneWidget);
    expect(find.text('本局固定，开始后不能更改'), findsOneWidget);
    expect(find.text('少年'), findsOneWidget);
    expect(find.text('掌柜'), findsOneWidget);

    await tester.tap(find.text('掌柜'));
    await tester.pumpAndSettle();

    expect(picked, 'c_keeper');
    expect(find.text('你扮演谁'), findsNothing);
  });
}
