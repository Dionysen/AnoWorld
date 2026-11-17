import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_chat_bubble.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
          isUser: false,
          avatarLabel: '旁白',
        ),
      ),
    );
    expect(find.textContaining('今晚别走'), findsOneWidget);
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
