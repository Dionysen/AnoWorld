import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_chat_dialogue_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splits blank-line paragraphs with spacing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: AppChatDialogueText(
            text: '第一段\n\n第二段',
            paragraphSpacing: 12,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('第一段', findRichText: true), findsOneWidget);
    expect(find.text('第二段', findRichText: true), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
  });
}
