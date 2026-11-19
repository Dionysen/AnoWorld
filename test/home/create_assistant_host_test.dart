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
                          builder: (_) => const Scaffold(
                            body: Text('故事详情'),
                          ),
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
                      builder: (_) => const AlertDialog(
                        content: Text('选择故事'),
                      ),
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
    expect(find.text('创作助手'), findsNothing);
    expect(find.byTooltip('创作助手'), findsOneWidget);
  });

  testWidgets('panel keeps its state while a popup covers it', (
    tester,
  ) async {
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
    expect(find.text('创作助手'), findsOneWidget);

    popup = _FakePopupRoute();
    controller.onRoutePushed(popup);
    await tester.pumpAndSettle();
    expect(find.text('创作助手'), findsNothing);

    controller.onRoutePopped(popup);
    await tester.pumpAndSettle();
    expect(find.text('创作助手'), findsOneWidget);
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
    expect(find.text('创作助手'), findsOneWidget);

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
      expect(find.text('创作助手'), findsOneWidget);

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
