import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = Key('press_target');

  Matrix4 _matrixOf(WidgetTester tester) {
    return tester
        .widget<Transform>(find.byKey(AppPressScale.transformKey))
        .transform;
  }

  testWidgets('AppPressScale shrinks while pressed then restores', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPressScale(
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  key: target,
                  width: 80,
                  height: 40,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(target));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    final pressed = _matrixOf(tester);
    expect(pressed.entry(0, 0), closeTo(AppTheme.pressScale, 0.001));
    expect(pressed.entry(1, 1), closeTo(AppTheme.pressScale, 0.001));

    await gesture.up();
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    final released = _matrixOf(tester);
    expect(released.entry(0, 0), closeTo(1.0, 0.001));
    expect(released.entry(1, 1), closeTo(1.0, 0.001));
  });

  testWidgets('AppPressScale can use a gentler X scale for wide rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPressScale(
              scaleX: AppTheme.pressScaleWideX,
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  key: target,
                  width: 320,
                  height: 56,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(target));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    final pressed = _matrixOf(tester);
    expect(pressed.entry(0, 0), closeTo(AppTheme.pressScaleWideX, 0.001));
    expect(pressed.entry(1, 1), closeTo(AppTheme.pressScale, 0.001));

    await gesture.up();
  });

  testWidgets('AppPressScale stays at 1 when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPressScale(
              enabled: false,
              child: SizedBox(
                key: target,
                width: 80,
                height: 40,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(target));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    final scale = _matrixOf(tester);
    expect(scale.entry(0, 0), closeTo(1.0, 0.001));
    expect(scale.entry(1, 1), closeTo(1.0, 0.001));

    await gesture.up();
  });
}
