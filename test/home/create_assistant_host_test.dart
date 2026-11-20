import 'dart:async';

import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/home/create_assistant_controller.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:anoworld/home/create_assistant_host.dart';
import 'package:anoworld/home/create_assistant_overlay.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

const _worldPatchJson = '''
{"ops":[
  {"op":"upsert_entry","id":"bg_world","body":"边陲小城常年下雨。"},
  {"op":"upsert_entry","title":"渡口","body":"夜里停摆。"}
]}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('overlay stays mounted and only toggles visibility', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CreateAssistantController();
    final overlayKey = GlobalKey<CreateAssistantOverlayScopeState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: CreateAssistantOverlayScope(
          key: overlayKey,
          controller: controller,
          child: const Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreateAssistantHost), findsOneWidget);
    expect(find.byTooltip('创作助手'), findsNothing);

    controller.setHomeStories(true);
    await tester.pumpAndSettle();
    expect(find.byTooltip('创作助手'), findsOneWidget);

    final hostState = tester.state<CreateAssistantHostState>(
      find.byType(CreateAssistantHost),
    );
    controller.setHomeStories(false);
    await tester.pumpAndSettle();
    expect(find.byTooltip('创作助手'), findsNothing);
    expect(
      tester.state<CreateAssistantHostState>(find.byType(CreateAssistantHost)),
      same(hostState),
    );
  });

  testWidgets('story slide route keeps assistant visible', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CreateAssistantController();
    final overlayKey = GlobalKey<CreateAssistantOverlayScopeState>();
    final observer = CreateAssistantNavigatorObserver(
      controller,
      onStackChanged: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          overlayKey.currentState?.bringToFront();
        });
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        navigatorObservers: [observer],
        home: CreateAssistantOverlayScope(
          key: overlayKey,
          controller: controller,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        AppStorySlidePageRoute<void>(
                          builder: (_) => const Scaffold(body: Text('故事详情')),
                        ),
                      );
                    },
                    child: const Text('打开'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    controller.setHomeStories(true);
    await tester.pumpAndSettle();
    expect(find.byTooltip('创作助手'), findsOneWidget);

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('故事详情'), findsOneWidget);
    expect(find.byTooltip('创作助手'), findsOneWidget);
  });

  testWidgets('assistant chrome hides under an open sheet / dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CreateAssistantController();
    final overlayKey = GlobalKey<CreateAssistantOverlayScopeState>();
    final observer = CreateAssistantNavigatorObserver(
      controller,
      onStackChanged: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          overlayKey.currentState?.bringToFront();
        });
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        navigatorObservers: [observer],
        home: CreateAssistantOverlayScope(
          key: overlayKey,
          controller: controller,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(content: Text('选择故事')),
                    ),
                    child: const Text('打开对话框'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    controller.setHomeStories(true);
    await tester.pumpAndSettle();
    expect(find.byTooltip('创作助手'), findsOneWidget);
    final fabCenter = tester.getCenter(find.byTooltip('创作助手'));

    await tester.tap(find.text('打开对话框'));
    await tester.pumpAndSettle();
    expect(find.text('选择故事'), findsOneWidget);
    expect(controller.modalOpen, isTrue);
    // Hidden, not covered: the button is not painted while the dialog is up.
    expect(find.byTooltip('创作助手'), findsNothing);

    // Tapping where the FAB used to be hits the dialog barrier instead.
    await tester.tapAt(fabCenter);
    await tester.pumpAndSettle();
    expect(find.text('选择故事'), findsNothing);
    expect(find.text('当前故事'), findsNothing);
    expect(find.byTooltip('创作助手'), findsOneWidget);
  });

  testWidgets('panel keeps its state while a popup covers it', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CreateAssistantController();
    late final _FakePopupRoute popup;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: CreateAssistantOverlayScope(
          controller: controller,
          child: const Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    controller.setHomeStories(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('创作助手'));
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsOneWidget);

    popup = _FakePopupRoute();
    controller.onRoutePushed(popup);
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsNothing);

    controller.onRoutePopped(popup);
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsOneWidget);
  });

  testWidgets('tapping outside the bloom dismisses the assistant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CreateAssistantController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: CreateAssistantOverlayScope(
          controller: controller,
          child: const Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    controller.setHomeStories(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('创作助手'));
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsOneWidget);

    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsNothing);
    expect(find.byTooltip('创作助手'), findsOneWidget);
  });

  testWidgets('tapping empty shell corner left of the anchor also dismisses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CreateAssistantController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: CreateAssistantOverlayScope(
          controller: controller,
          child: const Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    controller.setHomeStories(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('创作助手'));
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsOneWidget);

    final size = tester.getSize(find.byType(CreateAssistantHost));
    await tester.tapAt(Offset(size.width * 0.35, size.height - 28));
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsNothing);
    expect(find.byTooltip('创作助手'), findsOneWidget);
  });

  testWidgets('collapsing the bloom keeps a running turn alive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = MemoryProjectRepository(
      seed: {'p1': const ProjectFactory().createRainNightSample()},
    );
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDraft(
        projectId: 'p1',
        projectTitle: '雨夜投宿',
        composer: '',
        lines: [],
      ),
    );
    final settings = testSettingsController();
    await settings.updateAi(
      settings.ai.copyWith(
        text: const AiTextEndpoint(
          kind: AiTextProviderKind.openAiCompatible,
          baseUrl: 'http://localhost:8080/v1',
          apiKey: 'sk',
          model: 'demo',
        ),
      ),
    );
    final client = _BlockingTextClient();
    final controller = CreateAssistantController();

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        settings: settings,
        textClient: client,
        home: CreateAssistantOverlayScope(
          controller: controller,
          child: const Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    controller.setHomeStories(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('创作助手'));
    await tester.pumpAndSettle();
    expect(find.text('雨夜投宿'), findsOneWidget);
    final panelBefore = tester.state<CreateAssistantPanelState>(
      find.byType(CreateAssistantPanel),
    );

    await tester.enterText(find.byType(TextField), '先写两站');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();

    // Hide the panel mid-turn: the pending turn must keep running and land
    // in the transcript once the model answers.
    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsNothing);
    expect(
      tester.state<CreateAssistantPanelState>(
        find.byType(CreateAssistantPanel, skipOffstage: false),
      ),
      same(panelBefore),
    );

    client.release();
    await tester.pumpAndSettle();

    expect(
      find.text(_BlockingTextClient.answer, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('review sheet opens when a hidden turn stages changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = MemoryProjectRepository(
      seed: {'proj_rain_night': const ProjectFactory().createRainNightSample()},
    );
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDraft(
        projectId: 'proj_rain_night',
        projectTitle: '雨夜投宿',
        composer: '',
        lines: [],
      ),
    );
    final settings = testSettingsController();
    await settings.updateAi(
      settings.ai.copyWith(
        text: const AiTextEndpoint(
          kind: AiTextProviderKind.openAiCompatible,
          baseUrl: 'http://localhost:8080/v1',
          apiKey: 'sk',
          model: 'demo',
        ),
      ),
    );
    final client = _BlockingTextClient(_worldPatchJson);
    final controller = CreateAssistantController();
    final overlayKey = GlobalKey<CreateAssistantOverlayScopeState>();
    final observer = CreateAssistantNavigatorObserver(
      controller,
      onStackChanged: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          overlayKey.currentState?.bringToFront();
        });
      },
    );

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        settings: settings,
        textClient: client,
        navigatorObservers: [observer],
        home: CreateAssistantOverlayScope(
          key: overlayKey,
          controller: controller,
          child: const Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    controller.setHomeStories(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('创作助手'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '世界观改冷一点');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();

    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(find.text('当前故事'), findsNothing);

    client.release();
    await tester.pumpAndSettle();

    // The review sheet is the only thing the hidden turn needs to surface.
    expect(find.text('当前故事'), findsNothing);
    expect(find.text('这次要改这些'), findsOneWidget);
    await tester.tap(find.textContaining('写入选中的'));
    await tester.pumpAndSettle();

    final saved = await repo.open('proj_rain_night');
    expect(
      saved.worldBook.entries.any((entry) => entry.body.contains('边陲小城常年下雨')),
      isTrue,
    );
  });

  testWidgets('panel restores draft from store', (tester) async {
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDraft(
        projectId: 'p1',
        projectTitle: '雨夜投宿',
        composer: '草稿输入',
        lines: [CreateAssistantDraftLine(role: 'user', text: '上一句')],
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

class _FakePopupRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return const SizedBox.shrink();
  }
}

/// Holds every model call until [release], so a test can hide the panel while
/// a turn is genuinely in flight.
class _BlockingTextClient implements AiTextClient, AiToolTurnClient {
  _BlockingTextClient([this.reply = answer]);

  static const answer = '好的，先写两站';

  final String reply;
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    await _gate.future;
    return AiTextCompletion(content: reply);
  }

  @override
  Future<OpenAiChatCompletion> completeTurn({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    List<OpenAiTool> tools = const <OpenAiTool>[],
    GenerationPreset? generation,
  }) async {
    await _gate.future;
    return OpenAiChatCompletion(content: reply);
  }
}
