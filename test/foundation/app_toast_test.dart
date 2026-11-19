import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('showAppToast appears under chrome and auto-dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      testScoped(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAppToast(context, '拖到下一站左侧插头，就能连上'),
                  child: const Text('tip'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('tip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey<String>('app_toast')), findsOneWidget);
    expect(find.text('拖到下一站左侧插头，就能连上'), findsOneWidget);

    final toast = tester.getRect(find.byKey(const ValueKey<String>('app_toast')));
    expect(toast.center.dx, closeTo(400, 1));
    expect(toast.top, greaterThanOrEqualTo(AppTheme.toastTopGap));

    await tester.pump(AppTheme.toastDuration);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('app_toast')), findsNothing);
  });

  testWidgets('new toast replaces the previous one', (tester) async {
    await tester.pumpWidget(
      testScoped(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showAppToast(context, '第一条'),
                    child: const Text('a'),
                  ),
                  TextButton(
                    onPressed: () => showAppToast(context, '第二条'),
                    child: const Text('b'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('第一条'), findsOneWidget);

    await tester.tap(find.text('b'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('第一条'), findsNothing);
    expect(find.text('第二条'), findsOneWidget);
  });

  testWidgets('tap does not dismiss; swipe sideways does', (tester) async {
    await tester.pumpWidget(
      testScoped(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAppToast(
                    context,
                    '可左右滑关掉',
                    duration: const Duration(seconds: 30),
                  ),
                  child: const Text('tip'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('tip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final toast = find.byKey(const ValueKey<String>('app_toast'));
    expect(toast, findsOneWidget);

    await tester.tap(toast);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(toast, findsOneWidget);

    await tester.drag(toast, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(toast, findsOneWidget);

    await tester.drag(toast, const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('app_toast')), findsNothing);
  });
}
