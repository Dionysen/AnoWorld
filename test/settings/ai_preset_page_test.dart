import 'package:anoworld/settings/ai_preset_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  Future<void> pumpPresetPage(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testScoped(home: const AiPresetPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('preset page shows current preset and its actions', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    expect(find.text('预设'), findsWidgets);
    expect(find.text('尚未选用'), findsOneWidget);
    expect(find.text('采样'), findsOneWidget);
    expect(find.text('预设提示词'), findsOneWidget);
    expect(find.text('温度'), findsOneWidget);
    expect(find.text('高级采样'), findsOneWidget);

    for (final tooltip in const [
      '新建预设',
      '保存当前设置为预设',
      '重命名当前预设',
      '删除当前预设',
      '导入预设',
      '导出预设',
      '加一条',
      '恢复默认顺序',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget);
    }
  });

  testWidgets('adds a custom prompt and deletes it from its editor', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    await tester.tap(find.byTooltip('加一条'));
    await tester.pumpAndSettle();
    expect(find.text('新建提示词'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '第二人称');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('已添加：第二人称'), findsOneWidget);

    final row = find.text('第二人称');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byTooltip('删除'), findsOneWidget);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除「第二人称」？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已删除'), findsOneWidget);
    expect(find.text('第二人称'), findsNothing);
  });

  testWidgets('multi-select deletes several custom prompts at once', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    for (final name in const ['甲', '乙']) {
      await tester.tap(find.byTooltip('加一条'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消多选'), findsOneWidget);
    expect(find.byTooltip('全选'), findsOneWidget);

    for (final name in const ['甲', '乙']) {
      final row = find.text(name);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }
    final count = find.text('已选 2');
    await tester.ensureVisible(count);
    await tester.pumpAndSettle();
    expect(count, findsOneWidget);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除这 2 项？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已删除'), findsOneWidget);
    expect(find.text('预设提示词'), findsOneWidget);
    expect(find.text('甲'), findsNothing);
    expect(find.text('乙'), findsNothing);
  });

  testWidgets('built-in prompt rows cannot be selected for deletion', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    await tester.tap(find.byTooltip('加一条'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '甲');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();

    final builtIn = find.text('系统提示');
    await tester.ensureVisible(builtIn);
    await tester.pumpAndSettle();
    await tester.tap(builtIn);
    await tester.pumpAndSettle();
    expect(find.text('内置提示词不能删除'), findsOneWidget);
    expect(find.byTooltip('删除'), findsNothing);
  });

  testWidgets('picker has no action buttons and no long-press menu', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    await tester.tap(find.text('尚未选用'));
    await tester.pumpAndSettle();
    expect(find.text('选择预设'), findsOneWidget);
    expect(find.text('内置'), findsOneWidget);
    expect(find.text('导入'), findsNothing);
    expect(find.text('存为预设'), findsNothing);

    await tester.tapAt(const Offset(8, 200));
    await tester.pumpAndSettle();
    expect(find.text('选择预设'), findsNothing);
  });

  testWidgets('selection header fits a narrow window', (tester) async {
    await pumpPresetPage(tester, size: const Size(260, 640));

    final add = find.byTooltip('加一条');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '甲');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final multi = find.byTooltip('多选');
    await tester.ensureVisible(multi);
    await tester.pumpAndSettle();
    await tester.tap(multi);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final row = find.text('甲');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final delete = find.byTooltip('删除');
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    expect(delete, findsOneWidget);
  });

  testWidgets('advances without custom prompts show no multi-select entry', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    expect(find.byTooltip('多选'), findsNothing);
    expect(find.byTooltip('加一条'), findsOneWidget);
  });

  testWidgets('advanced sampling and prompt order shortcuts work', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    await tester.tap(find.text('高级采样'));
    await tester.pumpAndSettle();
    expect(find.text('Top K'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('恢复默认顺序'));
    await tester.pumpAndSettle();
    expect(find.text('已恢复默认顺序'), findsOneWidget);
  });

  testWidgets('renaming and deleting ask for a custom preset', (tester) async {
    await pumpPresetPage(tester);

    await tester.tap(find.byTooltip('重命名当前预设'));
    await tester.pumpAndSettle();
    expect(find.text('还没有选用预设'), findsOneWidget);

    await tester.tap(find.byTooltip('删除当前预设'));
    await tester.pumpAndSettle();
    expect(find.text('还没有选用预设'), findsOneWidget);
  });

  testWidgets('action row wraps instead of overflowing on a narrow window', (
    tester,
  ) async {
    await pumpPresetPage(tester, size: const Size(260, 640));

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('新建预设'), findsOneWidget);
    expect(find.byTooltip('导出预设'), findsOneWidget);
  });

  testWidgets('create, rename and delete custom preset from the toolbar', (
    tester,
  ) async {
    await pumpPresetPage(tester);

    await tester.tap(find.byTooltip('新建预设'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('已新建：新预设'), findsOneWidget);

    await tester.tap(find.byTooltip('重命名当前预设'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '雨夜口吻');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('已改名：雨夜口吻'), findsOneWidget);

    await tester.tap(find.byTooltip('删除当前预设'));
    await tester.pumpAndSettle();
    expect(find.text('删除「雨夜口吻」？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已删除'), findsOneWidget);
    expect(find.text('尚未选用'), findsOneWidget);
  });
}
