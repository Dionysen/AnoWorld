import 'package:anoworld/home/play_modes_tab.dart';
import 'package:anoworld/play/plot_element_category_page.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('play modes tab opens plot elements library', (tester) async {
    await tester.pumpWidget(
      testScoped(home: const PlayModesTab()),
    );
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
    expect(find.text('新建分类'), findsOneWidget);

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

  testWidgets('new category can be created from the category tab', (
    tester,
  ) async {
    final settings = testSettingsController();
    await tester.pumpWidget(
      testScoped(settings: settings, home: const PlotElementsLibraryPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('新建分类'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '校园');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(settings.plotElements.customCategories.single.name, '校园');
    expect(find.text('校园'), findsOneWidget);
  });
}
