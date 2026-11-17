import 'package:anoworld/foundation/theme/app_chat_background.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_chat_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson restores gradient', () {
    const original = AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#10131B', '#2A3348'],
      gradientAngle: 180,
    );
    final restored = AppChatBackground.fromJson(original.toJson());
    expect(restored, original);
    expect(restored.toGradient(), isNotNull);
  });

  test('matches ignores hash case', () {
    final a = AppChatBackground.solid('#aabbcc');
    final b = AppChatBackground.solid('#AABBCC');
    expect(a.matches(b), isTrue);
  });

  testWidgets('layer paints solid over theme chat canvas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dataFor(brightness: Brightness.dark),
        home: Scaffold(
          body: AppChatBackgroundLayer(
            background: AppChatBackground.solid('#112233'),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(find.byType(AppChatBackgroundLayer), findsOneWidget);
    expect(find.byType(ColoredBox), findsWidgets);
  });
}
