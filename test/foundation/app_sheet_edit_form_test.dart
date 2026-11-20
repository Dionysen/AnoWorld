import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Widget _hostForSheet({required double width}) {
  return testLocalized(
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: AppButton(
                label: '打开',
                onPressed: () => showAppSheet<void>(
                  context: context,
                  size: AppSheetSize.half,
                  builder: (_) => AppSheetEditForm(
                    title: '编辑角色',
                    isDirty: true,
                    onSave: () {},
                    body: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets('edit sheet header never overflows a narrow window', (
    tester,
  ) async {
    for (final width in <double>[180, 130]) {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_hostForSheet(width: width));
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('保存'), findsOneWidget);
      // Stacked: the save button sits below the title instead of beside it.
      expect(
        tester.getTopLeft(find.widgetWithText(AppButton, '保存')).dy,
        greaterThan(tester.getTopLeft(find.text('编辑角色')).dy),
      );

      // Drop the previous tree (and its sheet route) before the next width.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('edit sheet keeps title and save on one row when wide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_hostForSheet(width: 420));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final titleY = tester.getCenter(find.text('编辑角色')).dy;
    final saveY = tester.getCenter(find.widgetWithText(AppButton, '保存')).dy;
    expect(saveY, closeTo(titleY, 2));
  });
}
