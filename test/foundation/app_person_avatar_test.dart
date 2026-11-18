import 'package:anoworld/foundation/widgets/app_person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders circular person avatar at given size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPersonAvatar(size: 48, semanticLabel: 'me'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.bySemanticsLabel('me'), findsOneWidget);
    final sized = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(AppPersonAvatar),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(sized.width, 48);
    expect(sized.height, 48);
  });
}
