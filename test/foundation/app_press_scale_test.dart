import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = Key('press_target');

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

    final pressed = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(pressed.scale, AppTheme.pressScale);

    await gesture.up();
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    final released = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(released.scale, 1.0);
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

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.0);

    await gesture.up();
  });
}
