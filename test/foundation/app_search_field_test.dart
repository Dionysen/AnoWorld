import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/app_continuous_input_border.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppSearchField stays capsule when corner radius is square', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dataFor(
          brightness: Brightness.dark,
          appearance: AppearanceSettings(cornerRadius: 0),
        ),
        home: const Scaffold(
          body: AppSearchField(hint: '搜索故事'),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration?.enabledBorder;
    expect(border, isA<AppContinuousInputBorder>());
    expect(
      (border! as AppContinuousInputBorder).borderRadius,
      AppSearchField.capsuleRadius,
    );
    expect(AppSearchField.capsuleRadius.topLeft.x, AppSearchField.height / 2);
  });
}
