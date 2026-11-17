import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a fixed circle independent of corner radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            AppUiTokens.fallback.copyWith(radius: 0),
          ],
        ),
        home: Scaffold(
          body: AppCircleButton(
            icon: Icons.arrow_back,
            tooltip: '返回',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.style?.shape?.resolve({}), isA<CircleBorder>());
    expect(tester.getSize(find.byType(IconButton)), const Size(40, 40));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            AppUiTokens.fallback.copyWith(radius: 24),
          ],
        ),
        home: Scaffold(
          body: AppCircleButton(
            icon: Icons.arrow_back,
            tooltip: '返回',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final again = tester.widget<IconButton>(find.byType(IconButton));
    expect(again.style?.shape?.resolve({}), isA<CircleBorder>());
    expect(tester.getSize(find.byType(IconButton)), const Size(40, 40));
  });

  testWidgets('default variant has no resting fill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppCircleButton(
            icon: Icons.arrow_back,
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.style?.backgroundColor?.resolve({}),
      Colors.transparent,
    );
  });

  testWidgets('fab constructor uses larger hit target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppCircleButton.fab(
            icon: Icons.play_arrow_rounded,
            tooltip: '开始游玩',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(IconButton)),
      const Size(
        AppCircleButton.fabDiameter,
        AppCircleButton.fabDiameter,
      ),
    );
  });

  testWidgets('invokes onPressed', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppCircleButton(
            icon: Icons.arrow_back,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppCircleButton));
    expect(pressed, isTrue);
  });
}
