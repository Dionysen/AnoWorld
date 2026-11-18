import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:anoworld/home/create_assistant_host.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('tapping outside the bloom dismisses the assistant', (
    tester,
  ) async {
    // Panel content fades in only when height > minLayoutHeight (380);
    // need a tall enough viewport for 0.54 * height.
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const CreateAssistantHost(
          child: Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('创作助手'));
    await tester.pumpAndSettle();
    expect(find.text('创作助手'), findsOneWidget);

    // Top-left is outside the bottom-right bloom.
    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(find.text('创作助手'), findsNothing);
    expect(find.byTooltip('创作助手'), findsOneWidget);
  });

  testWidgets(
    'tapping empty shell corner left of the anchor also dismisses',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data,
          home: const CreateAssistantHost(
            child: Scaffold(body: ColoredBox(color: Colors.black)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('创作助手'));
      await tester.pumpAndSettle();
      expect(find.text('创作助手'), findsOneWidget);

      // Bottom strip: left of the circular anchor, still inside the shell box
      // but outside the bloom path — must reach the dismiss barrier.
      final size = tester.getSize(find.byType(CreateAssistantHost));
      await tester.tapAt(Offset(size.width * 0.35, size.height - 28));
      await tester.pumpAndSettle();
      expect(find.text('创作助手'), findsNothing);
      expect(find.byTooltip('创作助手'), findsOneWidget);
    },
  );

  testWidgets('panel restores draft from store', (tester) async {
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDraft(
        projectId: 'p1',
        projectTitle: '雨夜投宿',
        composer: '草稿输入',
        lines: [
          CreateAssistantDraftLine(role: 'user', text: '上一句'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 520,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('雨夜投宿'), findsOneWidget);
    expect(find.text('上一句'), findsOneWidget);
    expect(find.text('草稿输入'), findsOneWidget);
  });
}
