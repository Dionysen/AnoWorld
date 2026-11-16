import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toggles value on tap', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppSwitch(
                value: value,
                onChanged: (next) => setState(() => value = next),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });
}
