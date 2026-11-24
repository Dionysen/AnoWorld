import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('AppListTileStack uses hairlines not vertical gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppListTileStack(
            tiles: const [
              AppListTile(title: '一'),
              AppListTile(title: '二'),
              AppListTile(title: '三'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppListTile), findsNWidgets(3));
    expect(find.byType(AppListHairline), findsNWidgets(2));
  });

  testWidgets('tappable AppListTile presses with AppPressScale', (tester) async {
    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppListTile(
            title: '雨夜',
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppPressScale), findsOneWidget);

    final center = tester.getCenter(find.text('雨夜'));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      AppTheme.pressScale,
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.0,
    );
  });
}