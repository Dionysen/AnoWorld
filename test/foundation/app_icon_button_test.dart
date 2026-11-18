import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
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

  testWidgets('stays circular independent of corner radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            AppUiTokens.fallback.copyWith(radius: 0),
          ],
        ),
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.add,
            tooltip: '开始创作',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.style?.shape?.resolve({}), isA<CircleBorder>());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            AppUiTokens.fallback.copyWith(radius: 24),
          ],
        ),
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.add,
            tooltip: '开始创作',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final again = tester.widget<IconButton>(find.byType(IconButton));
    expect(again.style?.shape?.resolve({}), isA<CircleBorder>());
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
