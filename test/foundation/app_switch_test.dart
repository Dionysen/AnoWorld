import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.data,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('toggles value on tap', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            return AppSwitch(
              value: value,
              onChanged: (next) => setState(() => value = next),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('draws at the compact footprint', (tester) async {
    await tester.pumpWidget(
      _host(AppSwitch(value: true, onChanged: (_) {})),
    );

    expect(tester.getSize(find.byType(AppSwitch)), const Size(45, 30));
  });
}
