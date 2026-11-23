import 'package:anoworld/foundation/layout/app_pane_width.dart';
import 'package:anoworld/foundation/widgets/app_detail_pane.dart';
import 'package:anoworld/foundation/widgets/app_master_detail.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  Widget host({required Widget detail}) {
    return testLocalized(
      home: Scaffold(
        body: AppMasterDetail(
          primary: const Center(child: Text('master')),
          detail: detail,
          emptyLabel: '选一个故事看详情',
          paneWidth: AppPaneWidthController(),
          detailController: AppDetailPaneController(),
        ),
      ),
    );
  }

  testWidgets('a page inside the detail pane drops its back button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var backs = 0;
    await tester.pumpWidget(
      host(
        detail: AppPage(
          key: const ValueKey<String>('pane-root'),
          title: '情节元素',
          onBack: () => backs++,
          body: const Text('pane body'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('master'), findsOneWidget);
    expect(find.text('情节元素'), findsOneWidget);
    expect(find.text('pane body'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    // Title sits in the pane's own first 44px row: the window chrome band is
    // not repeated inside the split.
    expect(tester.getTopLeft(find.text('情节元素')).dy, lessThan(44));
  });

  testWidgets('a page pushed on top of the pane keeps its back button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        detail: AppPage(
          key: const ValueKey<String>('pane-root'),
          title: '情节元素',
          onBack: () {},
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => pushAppSlide<void>(
                  context,
                  AppPage(
                    title: '编辑元素',
                    onBack: () => Navigator.of(context).pop(),
                    body: const Text('editor body'),
                  ),
                ),
                child: const Text('打开编辑'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    // Inside the column, one level down: the list is not the way back anymore.
    expect(find.text('master'), findsOneWidget);
    expect(find.text('编辑元素'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('editor body'), findsNothing);
    expect(find.text('情节元素'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('the same page keeps its back button outside a pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testLocalized(
        home: AppPage(
          title: '情节元素',
          onBack: () {},
          body: const Text('page body'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    // Window chrome band pushes the software title bar below it.
    expect(tester.getTopLeft(find.text('情节元素')).dy, greaterThan(44));
  });
}
