import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppSlider.snap rounds to step within range', () {
    expect(
      AppSlider.snap(value: 10.4, min: 0, max: 24, step: 1),
      10,
    );
    expect(
      AppSlider.snap(value: 1.07, min: 0.85, max: 1.3, step: 0.05),
      closeTo(1.05, 0.0001),
    );
    expect(
      AppSlider.snap(value: 99, min: 0, max: 24, step: 1),
      24,
    );
  });

  testWidgets('AppSlider opens a sheet slider and reports snapped values', (
    tester,
  ) async {
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppSlider(
            label: '圆角大小',
            subtitle: '按钮和卡片的圆角',
            value: 10,
            min: 0,
            max: 24,
            step: 1,
            onChanged: values.add,
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsNothing);
    expect(find.text('按钮和卡片的圆角'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.text('圆角大小'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(values.last, inInclusiveRange(0, 24));
    expect(values.last, equals(values.last.roundToDouble()));
  });

  testWidgets('AppSlider row shows label, subtitle and value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AppSlider(
              label: '字体大小',
              subtitle: '界面里的字有多大',
              value: 15,
              min: 12,
              max: 20,
              step: 0.5,
              valueText: _px,
              onChanged: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('字体大小'), findsOneWidget);
    expect(find.text('界面里的字有多大'), findsOneWidget);
    expect(find.text('15 px'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });
}

String _px(double v) =>
    '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} px';

void _noop(double _) {}
