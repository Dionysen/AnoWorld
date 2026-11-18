import 'package:anoworld/foundation/focus/app_keyboard.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppKeyboard.dismiss unfocuses text field', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
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
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    AppKeyboard.dismiss();
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget is EditableText,
      isFalse,
    );
  });
}
