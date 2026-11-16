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

  testWidgets('AppSlider reports snapped values', (tester) async {
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppSlider(
            label: '圆角大小',
            value: 10,
            min: 0,
            max: 24,
            step: 1,
            onChanged: values.add,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(values.last, inInclusiveRange(0, 24));
    expect(values.last, equals(values.last.roundToDouble()));
  });

  testWidgets('AppSlider keeps label and value inside the surface block', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AppSlider(
              label: '字体大小',
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

    final block = tester.getRect(find.byType(Material).last);
    final label = tester.getRect(find.text('字体大小'));
    final value = tester.getRect(find.text('15 px'));
    final track = tester.getRect(find.byType(Slider));

    expect(block.contains(label.topLeft), isTrue);
    expect(block.contains(label.bottomRight), isTrue);
    expect(block.contains(value.topLeft), isTrue);
    expect(block.contains(value.bottomRight), isTrue);
    expect(block.contains(track.center), isTrue);
  });
}

String _px(double v) =>
    '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} px';

void _noop(double _) {}

