import 'package:anoworld/create/staged_create_page.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

class _NoCallTextClient implements AiTextClient {
  @override
  Future<String> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
  }) async {
    fail('should not call text client');
  }
}

void main() {
  testWidgets('shows config hint when text AI is not set up', (tester) async {
    final settings = testSettingsController();
    await tester.pumpWidget(
      testScoped(
        home: const StagedCreatePage(),
        settings: settings,
        textClient: _NoCallTextClient(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '雨夜边城');
    await tester.tap(find.widgetWithText(AppButton, '生成'));
    await tester.pump();

    expect(find.textContaining('设置里配好'), findsOneWidget);
  });
}
