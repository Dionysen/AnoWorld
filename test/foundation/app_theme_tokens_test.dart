import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/app_continuous_input_border.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme embeds AppUiTokens from appearance', () {
    final theme = AppTheme.dark(
      AppearanceSettings(
        fontFamily: 'Roboto',
        fontSize: 16.5,
        cornerRadius: 16,
      ),
    );

    final tokens = theme.extension<AppUiTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.radius, 16);
    expect(tokens.fontSize, 16.5);
    expect(tokens.fontFamily, 'Roboto');
    expect(tokens.fieldPadding, AppTheme.fieldPadding);
    expect(
      theme.textTheme.bodyLarge!.fontSize,
      closeTo(15 * (16.5 / 15), 0.01),
    );
    expect(
      theme.inputDecorationTheme.border,
      isA<AppContinuousInputBorder>(),
    );
    expect(theme.inputDecorationTheme.contentPadding, AppTheme.fieldPadding);
    expect(tokens.shape(), isA<RoundedSuperellipseBorder>());
  });

  testWidgets('AppTextField uses theme content padding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(AppearanceSettings()),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(8),
            child: AppTextField(label: 'Base URL', hint: 'https://'),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(TextField));
    expect(
      Theme.of(context).inputDecorationTheme.contentPadding,
      AppTheme.fieldPadding,
    );
  });
}
