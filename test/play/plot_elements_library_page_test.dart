import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/home/play_modes_tab.dart';
import 'package:anoworld/play/plot_element_category_page.dart';
import 'package:anoworld/play/plot_element_pack_page.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:anoworld/settings/ai_preset_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('play modes tab opens plot elements library', (tester) async {
    await tester.pumpWidget(testScoped(home: const PlayModesTab()));
    await tester.pumpAndSettle();

    expect(find.text('玩法还在整理'), findsNothing);
    expect(find.text('剧情元素'), findsOneWidget);
    expect(find.text('全局库，给故事勾着用'), findsOneWidget);

    await tester.tap(find.text('剧情元素'));
    await tester.pumpAndSettle();
    expect(find.byType(PlotElementsLibraryPage), findsOneWidget);
    expect(find.text('剧情元素库'), findsOneWidget);
    expect(find.text('全局库'), findsNothing);
    expect(find.text('救助流浪猫'), findsOneWidget);
  });

  testWidgets('play modes tab opens preset page', (tester) async {
    await tester.pumpWidget(testScoped(home: const PlayModesTab()));
    await tester.pumpAndSettle();

    expect(find.text('预设'), findsOneWidget);
    expect(find.text('输出风格、采样与提示词'), findsOneWidget);

    await tester.tap(find.text('预设'));
    await tester.pumpAndSettle();
    expect(find.byType(AiPresetPage), findsOneWidget);
    expect(find.text('采样'), findsOneWidget);
  });

  testWidgets('category tab lists categories that open their own page', (
    tester,
  ) async {
    final settings = testSettingsController();
    await tester.pumpWidget(
      testScoped(settings: settings, home: const PlotElementsLibraryPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();

    expect(find.text('日常'), findsOneWidget);
    expect(find.text('情感'), findsOneWidget);
    expect(find.text('新建分类'), findsNothing);
    expect(find.byTooltip('新建分类'), findsOneWidget);
    expect(find.byTooltip('加一条'), findsOneWidget);

    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();

    expect(find.byType(PlotElementCategoryPage), findsOneWidget);
    expect(find.text('救助流浪猫'), findsOneWidget);
    expect(find.text('8 条'), findsOneWidget);

    // Rename the category from its page.
    await tester.tap(find.byTooltip('重命名分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '生活');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(settings.plotElements.categoryNameOf('pe_cat_daily'), '生活');
    expect(find.text('生活'), findsOneWidget);
  });

  testWidgets('top-right button creates a category on the category tab', (
    tester,
  ) async {
    final settings = testSettingsController();
    await tester.pumpWidget(
      testScoped(settings: settings, home: const PlotElementsLibraryPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '校园');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(settings.plotElements.customCategories.single.name, '校园');
    expect(find.text('校园'), findsOneWidget);
  });

  testWidgets('title bar shows more / add / new-category buttons', (
    tester,
  ) async {
    await tester.pumpWidget(testScoped(home: const PlotElementsLibraryPage()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('更多'), findsOneWidget);
    expect(find.byTooltip('加一条'), findsOneWidget);
    expect(find.byTooltip('新建分类'), findsOneWidget);

    await tester.tap(find.byTooltip('加一条'));
    await tester.pumpAndSettle();
    expect(find.text('新剧情元素'), findsOneWidget);
  });

  testWidgets('pack tab creates a pack and toggles its elements', (
    tester,
  ) async {
    final settings = testSettingsController();
    await tester.pumpWidget(
      testScoped(settings: settings, home: const PlotElementsLibraryPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('包'));
    await tester.pumpAndSettle();

    expect(find.text('还没有包'), findsOneWidget);
    expect(find.byTooltip('新建包'), findsOneWidget);
    expect(find.byTooltip('新建分类'), findsNothing);
    expect(find.byTooltip('加一条'), findsOneWidget);

    await tester.tap(find.byTooltip('新建包'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '雨夜包');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(PlotElementPackPage), findsOneWidget);
    expect(settings.plotElements.packs.single.name, '雨夜包');
    expect(find.text('还空着'), findsOneWidget);

    await tester.tap(find.text('救助流浪猫'));
    await tester.pumpAndSettle();
    expect(settings.plotElements.packs.single.elementIds, ['pe_stray_cat']);
    expect(find.text('1 条'), findsOneWidget);

    await tester.tap(find.byTooltip('重命名包'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '雨夜悬疑');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(settings.plotElements.packs.single.name, '雨夜悬疑');
  });

  testWidgets('pack tab lists packs with their element preview', (
    tester,
  ) async {
    final settings = testSettingsController();
    await settings.updatePlotElements(
      settings.plotElements.upsertPack(
        const PlotElementPack(
          id: 'pe_pack_list',
          name: '雨夜包',
          elementIds: ['pe_stray_cat', 'pe_shared_umbrella'],
        ),
      ),
    );
    await tester.pumpWidget(
      testScoped(settings: settings, home: const PlotElementsLibraryPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('包'));
    await tester.pumpAndSettle();

    expect(find.text('雨夜包'), findsOneWidget);
    expect(find.textContaining('2 条'), findsOneWidget);
    expect(find.text('还没有包'), findsNothing);
  });

  testWidgets('more menu only keeps restore-all', (tester) async {
    await tester.pumpWidget(testScoped(home: const PlotElementsLibraryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('全部恢复默认'), findsOneWidget);
    expect(find.text('加一条'), findsNothing);
  });
}
