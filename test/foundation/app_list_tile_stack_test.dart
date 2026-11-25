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

  testWidgets('narrow AppListTile hides trailing before overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: SizedBox(
            // Content ≈ 128 after horizontal page padding — fits leading+title,
            // not trailing (mirrors the logged 127px overflow case).
            width: 160,
            child: AppListTile(
              title: '剧情元素',
              subtitle: '故事选用的情节素材',
              leading: const SizedBox(
                key: Key('leading'),
                width: 56,
                height: 56,
              ),
              trailing: const Icon(Icons.more_vert),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byKey(const Key('leading')), findsOneWidget);
    expect(find.text('剧情元素'), findsOneWidget);
  });

  testWidgets('onEdit shows edit control without firing onTap', (tester) async {
    var tapped = false;
    var edited = false;

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppListTile(
            title: '世界书',
            subtitle: '9 条设定，8 条常驻，9371 token',
            icon: Icons.public_outlined,
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: () => tapped = true,
            onEdit: () => edited = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('编辑'), findsOneWidget);
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();

    expect(edited, isTrue);
    expect(tapped, isFalse);
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

    final pressed = tester
        .widget<Transform>(find.byKey(AppPressScale.transformKey))
        .transform;
    expect(pressed.entry(0, 0), closeTo(AppTheme.pressScaleWideX, 0.001));
    expect(pressed.entry(1, 1), closeTo(AppTheme.pressScale, 0.001));

    await gesture.up();
    await tester.pump();
    await tester.pump(AppTheme.pressScaleDuration);

    final released = tester
        .widget<Transform>(find.byKey(AppPressScale.transformKey))
        .transform;
    expect(released.entry(0, 0), closeTo(1.0, 0.001));
    expect(released.entry(1, 1), closeTo(1.0, 0.001));
  });
}