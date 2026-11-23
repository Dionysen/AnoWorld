import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/layout/app_pane_width.dart';
import 'package:anoworld/foundation/widgets/app_detail_pane.dart';
import 'package:anoworld/foundation/widgets/app_master_detail.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  Widget host({
    Widget? detail,
    AppPaneWidthController? paneWidth,
    AppDetailPaneController? detailController,
  }) {
    return testLocalized(
      home: Scaffold(
        body: AppMasterDetail(
          primary: const Center(child: Text('master')),
          detail: detail,
          emptyLabel: '选一个故事看详情',
          paneWidth: paneWidth ?? AppPaneWidthController(),
          detailController: detailController ?? AppDetailPaneController(),
        ),
      ),
    );
  }

  testWidgets('narrow host renders the primary pane only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(detail: const Text('detail', key: ValueKey<String>('detail'))),
    );

    expect(find.text('master'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('app_master_detail_handle')),
      findsNothing,
    );
  });

  testWidgets('wide host shows both panes and the empty hint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(host());

    expect(find.text('master'), findsOneWidget);
    expect(find.text('选一个故事看详情'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('app_master_detail_handle')),
      findsOneWidget,
    );
  });

  testWidgets('wide host swaps the watermark for the detail widget', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(detail: const Text('detail', key: ValueKey<String>('detail'))),
    );

    expect(find.text('detail'), findsOneWidget);
    expect(find.text('选一个故事看详情'), findsNothing);
  });

  testWidgets('dragging the divider updates the shared width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paneWidth = AppPaneWidthController();

    await tester.pumpWidget(host(paneWidth: paneWidth));

    await tester.drag(
      find.byKey(const ValueKey<String>('app_master_detail_handle')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    expect(
      paneWidth.masterPaneWidth,
      greaterThan(AppLayout.masterPaneDefaultWidth),
    );
  });

  testWidgets('dragging past the detail minimum clamps the divider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paneWidth = AppPaneWidthController();

    await tester.pumpWidget(host(paneWidth: paneWidth));
    await tester.pumpAndSettle();

    // The detail pane must keep its minimum, so a huge drag cannot grow the
    // master pane without bound.
    await tester.drag(
      find.byKey(const ValueKey<String>('app_master_detail_handle')),
      const Offset(2000, 0),
    );
    await tester.pumpAndSettle();

    final contentWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(
      paneWidth.masterPaneWidth,
      contentWidth -
          AppLayout.detailPaneMinWidth -
          AppLayout.paneResizeHandleWidth,
    );
  });

  testWidgets('pages opened from the detail stay inside the column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppDetailPaneController();

    await tester.pumpWidget(
      host(detailController: controller, detail: _paneRoot('故事详情')),
    );
    await tester.pumpAndSettle();
    expect(controller.canPop, isFalse);

    await tester.tap(find.text('打开世界书'));
    await tester.pumpAndSettle();

    // The list survived, and the pushed page is the detail column's own.
    expect(find.text('master'), findsOneWidget);
    expect(find.text('世界书编辑'), findsOneWidget);
    // Deeper pages keep their own way back inside the column.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(controller.canPop, isTrue);

    expect(controller.pop(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('世界书编辑'), findsNothing);
    expect(find.text('master'), findsOneWidget);
    expect(controller.canPop, isFalse);
  });

  testWidgets('a new selection drops the stack opened on the old one', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppDetailPaneController();

    await tester.pumpWidget(
      host(detailController: controller, detail: _paneRoot('故事详情')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开世界书'));
    await tester.pumpAndSettle();
    expect(find.text('世界书编辑'), findsOneWidget);

    await tester.pumpWidget(
      host(detailController: controller, detail: _paneRoot('另一个故事')),
    );
    await tester.pumpAndSettle();

    expect(find.text('世界书编辑'), findsNothing);
    expect(find.text('另一个故事'), findsOneWidget);
    expect(controller.canPop, isFalse);
  });
}

/// Detail-pane root that opens an editor page inside the column.
Widget _paneRoot(String title) {
  return AppPage(
    key: ValueKey<String>('pane-root-$title'),
    title: title,
    onBack: () {},
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => pushAppSlide<void>(
            context,
            AppPage(
              title: '世界书编辑',
              onBack: () => Navigator.of(context).pop(),
              body: const Text('editor body'),
            ),
          ),
          child: const Text('打开世界书'),
        ),
      ),
    ),
  );
}
