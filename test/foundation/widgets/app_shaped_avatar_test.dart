import 'package:anoworld/foundation/widgets/app_shaped_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('AppShapedAvatar shows the child content', (tester) async {
    await tester.pumpWidget(
      testLocalized(
        home: const Scaffold(
          body: AppShapedAvatar(
            width: 40,
            height: 40,
            child: Text('A'),
          ),
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('AppShapedAvatar paints the background layer', (tester) async {
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: AppShapedAvatar.fromGeometry(
            width: 56,
            geometry: AppAvatarGeometry.rectangle,
            background: const ColoredBox(
              key: Key('cover'),
              color: Color(0xFFFF0000),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('cover')), findsOneWidget);
    final size = tester.getSize(find.byType(AppShapedAvatar));
    expect(size.width, 56);
    expect(size.height, closeTo(56 * 4 / 3, 0.01));
  });
}
