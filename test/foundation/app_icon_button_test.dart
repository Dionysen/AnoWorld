import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppIconButton defaults to 40 hit target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.folder_open,
            tooltip: '导入',
            onPressed: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(AppIconButton));
    expect(size.width, AppIconButton.hitTarget);
    expect(size.height, AppIconButton.hitTarget);
  });

  test('AppPage.spacedActions inserts spaceSm and drops SizedBox spacers', () {
    final spaced = AppPage.spacedActions([
      const Icon(Icons.folder_open),
      const SizedBox(width: 99),
      const Icon(Icons.more_vert),
    ]);
    expect(spaced.length, 3);
    expect(spaced[0], isA<Icon>());
    expect(spaced[1], isA<SizedBox>());
    expect((spaced[1] as SizedBox).width, AppTheme.spaceSm);
    expect(spaced[2], isA<Icon>());
  });
}
