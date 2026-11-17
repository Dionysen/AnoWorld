import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_chat_bubble.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppChatBubbleRole is exported from app_chat_bubble.dart.

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dataFor(brightness: Brightness.dark),
      home: Scaffold(body: child),
    );
  }

  testWidgets('AppChatBubble renders dialogue quotes', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppChatBubble(
          text: '他低声说「今晚别走」。',
          role: AppChatBubbleRole.narration,
        ),
      ),
    );
    expect(find.textContaining('今晚别走'), findsOneWidget);
  });

  testWidgets('character bubble shows name and body', (tester) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            AppChatBubble(
              text: '你会更开心吗？',
              role: AppChatBubbleRole.character,
              avatarLabel: '瑞希',
            ),
            AppChatBubble(
              text: '会。',
              role: AppChatBubbleRole.user,
              avatarLabel: 'User',
            ),
          ],
        ),
      ),
    );
    expect(find.text('瑞希'), findsOneWidget);
    expect(find.text('你会更开心吗？'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('会。'), findsOneWidget);
  });

  testWidgets('reasoning appears when enabled', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppChatBubble(
          text: '你好',
          role: AppChatBubbleRole.character,
          avatarLabel: '瑞希',
          reasoning: '先打招呼',
          showReasoning: true,
        ),
      ),
    );
    expect(find.text('思考过程'), findsOneWidget);
    await tester.tap(find.text('思考过程'));
    await tester.pumpAndSettle();
    expect(find.text('先打招呼'), findsOneWidget);
  });

  testWidgets('side avatar layout uses a row', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppChatBubble(
          text: '并排',
          role: AppChatBubbleRole.character,
          avatarLabel: '瑞希',
          avatarAboveBubble: false,
        ),
      ),
    );
    expect(find.byType(Row), findsWidgets);
    expect(find.text('并排'), findsOneWidget);
  });

  testWidgets('AppChatComposer send tap fires onSend', (tester) async {
    final controller = TextEditingController(text: '你好');
    var sent = false;
    await tester.pumpWidget(
      wrap(
        AppChatComposer(
          controller: controller,
          onSend: () => sent = true,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sent, isTrue);
  });
}
