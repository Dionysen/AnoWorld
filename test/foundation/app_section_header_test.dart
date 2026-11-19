import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.data,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders label and subtitle', (tester) async {
    await tester.pumpWidget(
      _host(
        AppSectionHeader('预设提示词', subtitle: '拖动手柄改顺序'),
      ),
    );

    expect(find.text('预设提示词'), findsOneWidget);
    expect(find.text('拖动手柄改顺序'), findsOneWidget);
  });

  testWidgets('trailing control sits on the title row, right aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppSectionHeader(
          '预设提示词',
          trailing: AppIconButton(
            icon: Icons.restart_alt_outlined,
            tooltip: '恢复默认顺序',
            onPressed: () {},
          ),
        ),
      ),
    );

    final label = tester.getRect(find.text('预设提示词'));
    final action = tester.getRect(find.byTooltip('恢复默认顺序'));
    expect(action.center.dy, moreOrLessEquals(label.center.dy, epsilon: 8));
    expect(action.right, greaterThan(label.right));
    expect(
      action.right,
      moreOrLessEquals(tester.getRect(find.byType(AppSectionHeader)).right),
    );

    await tester.tap(find.byTooltip('恢复默认顺序'));
  });
}
