import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppButton invokes onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppButton(
            label: '继续',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('继续'));
    expect(tapped, isTrue);
  });

  testWidgets('AppListTile shows title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: AppListTile(
            title: '雨夜投宿',
            subtitle: '更新 2026-01-01',
            icon: Icons.menu_book_outlined,
          ),
        ),
      ),
    );

    expect(find.text('雨夜投宿'), findsOneWidget);
    expect(find.text('更新 2026-01-01'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });

  testWidgets('AppListTile subtitle uses space up to the trailing control', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const subtitle = '浅色与深色各记一套';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AppListTile(
              title: '主题预设',
              subtitle: subtitle,
              icon: Icons.style_outlined,
              trailing: Icon(Icons.keyboard_arrow_down, size: 20),
            ),
          ),
        ),
      ),
    );

    final textRight = tester.getBottomRight(find.text(subtitle)).dx;
    final trailingLeft =
        tester.getTopLeft(find.byIcon(Icons.keyboard_arrow_down)).dx;
    // Text should reach near the chevron — not stop in the middle.
    expect(trailingLeft - textRight, lessThan(40));
    expect(find.text(subtitle), findsOneWidget);
  });

  testWidgets('AppSelectField labels outside like text field', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppSelectField(
            label: '模型',
            value: 'deepseek-flash',
            onTap: () => tapped = true,
            trailing: const AppButton(
              label: '探测模型',
              variant: AppButtonVariant.secondary,
              onPressed: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('模型'), findsOneWidget);
    expect(find.text('deepseek-flash'), findsOneWidget);
    expect(find.text('探测模型'), findsOneWidget);
    final labelY = tester.getTopLeft(find.text('模型')).dy;
    final valueY = tester.getTopLeft(find.text('deepseek-flash')).dy;
    expect(labelY, lessThan(valueY));
    final fieldHeight = tester.getSize(find.text('deepseek-flash').hitTestable()).height;
    final buttonHeight = tester.getSize(find.widgetWithText(AppButton, '探测模型')).height;
    expect(buttonHeight, AppTheme.buttonHeight);
    expect(fieldHeight, lessThanOrEqualTo(AppTheme.buttonHeight));
    await tester.tap(find.text('deepseek-flash'));
    expect(tapped, isTrue);
  });

  testWidgets('AppDisclosureIcon flips between down and up', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: Row(
            children: [
              AppDisclosureIcon(expanded: false),
              AppDisclosureIcon(expanded: true),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
  });

  testWidgets('AppButton variants share the same height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: Row(
            children: [
              AppButton(
                label: '取消',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
              AppButton(
                label: '完成',
                onPressed: () {},
              ),
              AppButton(
                label: '幽灵',
                variant: AppButtonVariant.ghost,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final cancel = tester.getSize(find.widgetWithText(AppButton, '取消'));
    final done = tester.getSize(find.widgetWithText(AppButton, '完成'));
    final ghost = tester.getSize(find.widgetWithText(AppButton, '幽灵'));
    expect(cancel.height, AppTheme.buttonHeight);
    expect(done.height, AppTheme.buttonHeight);
    expect(ghost.height, AppTheme.buttonHeight);
    expect(cancel.height, done.height);
  });

  testWidgets('AppButton does not overflow in a narrow strip', (tester) async {
    await tester.binding.setSurfaceSize(const Size(120, 80));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: SizedBox(
            width: 100,
            child: AppButton(
              label: '分阶段提示词入口很长',
              onPressed: null,
              expanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
