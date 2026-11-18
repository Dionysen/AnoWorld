import 'package:anoworld/foundation/focus/app_keyboard.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('focused AppTextField counts as text input focus', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardScope(
          child: Scaffold(
            body: Column(
              children: [
                AppTextField(
                  label: '测试',
                  controller: TextEditingController(text: 'a'),
                ),
                const SizedBox(
                  height: 200,
                  child: ColoredBox(color: Color(0xFF112233)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(AppKeyboard.isTextInputFocused, isTrue);

    await tester.tapAt(const Offset(50, 500));
    await tester.pump();
    expect(AppKeyboard.isTextInputFocused, isFalse);
  });
}
