import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds only visible rows and reveals the rest on scroll', (
    tester,
  ) async {
    var built = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPageLazyList(
            header: const [Text('头部')],
            itemCount: 400,
            itemBuilder: (context, index) {
              built++;
              return SizedBox(height: 48, child: Text('row $index'));
            },
          ),
        ),
      ),
    );

    expect(find.text('头部'), findsOneWidget);
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row 399'), findsNothing);
    expect(built, lessThan(400));

    await tester.scrollUntilVisible(find.text('row 399'), 800);

    expect(find.text('row 399'), findsOneWidget);
  });

  testWidgets('renders the header when there are no rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPageLazyList(
            header: const [Text('头部'), Text('空状态')],
            itemCount: 0,
            itemBuilder: (context, index) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('头部'), findsOneWidget);
    expect(find.text('空状态'), findsOneWidget);
  });
}
