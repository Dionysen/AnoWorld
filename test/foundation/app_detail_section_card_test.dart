import 'package:anoworld/foundation/widgets/app_detail_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('shows expand when body exceeds preview lines', (tester) async {
    var edited = false;
    const body = '第一行。\n第二行。\n第三行。\n第四行要撑开折叠。\n第五行继续。';

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSectionCard(
            title: '背景设定',
            icon: Icons.public_outlined,
            body: body,
            onEdit: () => edited = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('展开'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });
}