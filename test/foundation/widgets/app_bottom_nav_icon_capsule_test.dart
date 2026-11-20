import 'package:anoworld/foundation/widgets/app_bottom_nav_icon_capsule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('capsule shows its icon when idle', (tester) async {
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: Center(
            child: AppBottomNavIconCapsule(
              icon: Icons.auto_awesome_outlined,
              tooltip: '创作助手',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('busy capsule trades the icon for a progress ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: Center(
            child: AppBottomNavIconCapsule(
              icon: Icons.auto_awesome_outlined,
              tooltip: '创作助手',
              busy: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The ring stays inside the capsule, not spilling past its square.
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)).width,
      lessThanOrEqualTo(AppBottomNavIconCapsule.side),
    );
    // Still the same tap target: opening the panel shows the running turn.
    expect(find.byTooltip('创作助手'), findsOneWidget);
  });
}
