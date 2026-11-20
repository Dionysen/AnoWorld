import 'dart:convert';

import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/home/create_assistant_controller.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/full_graph_json.dart';
import '../support/test_app.dart';

/// One scripted model turn: plain text, or a single tool call.
class _Reply {
  const _Reply.text(this.text) : tool = null, args = const <String, dynamic>{};

  const _Reply.tool(this.tool, [this.args = const <String, dynamic>{}])
    : text = '';

  final String text;
  final String? tool;
  final Map<String, dynamic> args;
}

class _ScriptedTextClient implements AiTextClient, AiToolTurnClient {
  _ScriptedTextClient(this.replies);

  final List<_Reply> replies;
  int calls = 0;

  /// Messages of the last model turn, so tests can assert what it was told.
  List<OpenAiChatMessage> lastMessages = const <OpenAiChatMessage>[];

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    return AiTextCompletion(content: _next().text);
  }

  @override
  Future<OpenAiChatCompletion> completeTurn({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    List<OpenAiTool> tools = const <OpenAiTool>[],
    GenerationPreset? generation,
  }) async {
    final reply = _next();
    lastMessages = messages;
    final tool = reply.tool;
    if (tool == null) return OpenAiChatCompletion(content: reply.text);
    return OpenAiChatCompletion(
      content: reply.text,
      toolCalls: <OpenAiToolCall>[
        OpenAiToolCall(
          id: 'call_$calls',
          name: tool,
          arguments: jsonEncode(reply.args),
        ),
      ],
    );
  }

  _Reply _next() {
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return replies[calls++];
  }
}

final _graphJson = buildFullGraphJson();

const _worldPatchJson = '''
{"ops":[
  {"op":"upsert_entry","id":"bg_world","body":"边陲小城常年下雨。"},
  {"op":"upsert_entry","title":"渡口","body":"夜里停摆。"}
]}
''';

const _endpoint = AiTextEndpoint(
  kind: AiTextProviderKind.openAiCompatible,
  baseUrl: 'http://localhost:8080/v1',
  apiKey: 'sk',
  model: 'demo',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'story picker heads the panel and nothing else crowds the composer',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MemoryProjectRepository(
        seed: {
          'proj_rain_night': const ProjectFactory().createRainNightSample(),
        },
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

      await tester.pumpWidget(
        testScoped(
          projects: repo,
          textClient: _ScriptedTextClient(const []),
          home: Scaffold(
            body: SizedBox(
              width: 380,
              height: 640,
              child: CreateAssistantPanel(draftStore: store),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No static title: the story picker is the header.
      expect(find.text('创作助手'), findsNothing);
      expect(find.text('当前故事'), findsOneWidget);

      // The assistant always edits the whole story: no scope switch by the
      // send button, so the composer holds the field and send only.
      for (final label in ['情节图', '世界书', '角色', '全部']) {
        expect(find.byTooltip(label), findsNothing);
      }
      final send = tester.getRect(find.byTooltip('发送'));
      final field = tester.getRect(
        find.descendant(
          of: find.byType(AppChatComposer),
          matching: find.byType(TextField),
        ),
      );
      expect(send.left, greaterThan(field.center.dx));
    },
  );

  testWidgets('composer still fits a narrow panel', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDraft(
        projectId: 'proj_rain_night',
        projectTitle: '雨夜投宿',
        composer: '',
        lines: [],
      ),
    );

    await tester.pumpWidget(
      testScoped(
        textClient: _ScriptedTextClient(const []),
        home: Scaffold(
          body: SizedBox(
            width: 296,
            height: 620,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppChatComposer), findsOneWidget);
    expect(find.byTooltip('发送'), findsOneWidget);
  });

  testWidgets('writes a generated plot graph into the selected story', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
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
    await settings.updateAi(settings.ai.copyWith(text: _endpoint));

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        settings: settings,
        textClient: _ScriptedTextClient([_Reply.text(_graphJson)]),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 640,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('雨夜投宿'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '整图重写：今晚必须出城');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('生成的情节'), findsOneWidget);
    expect(find.textContaining('站'), findsWidgets);

    await tester.tap(find.text('写入选中的 1 条'));
    await tester.pumpAndSettle();

    final saved = await repo.open('proj_rain_night');
    expect(saved.main.nodes.length, greaterThanOrEqualTo(20));
    expect(saved.main.edges, isNotEmpty);
    expect(saved.main.beats, isEmpty);
    expect(find.text('情节图写好了，可以在情节图里继续调整'), findsOneWidget);
  });

  testWidgets('writes only the ticked ops from the review sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
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
    await settings.updateAi(settings.ai.copyWith(text: _endpoint));

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        settings: settings,
        textClient: _ScriptedTextClient([_Reply.text(_worldPatchJson)]),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 640,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '世界观改冷一点，再加一个渡口');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('这次要改这些'), findsOneWidget);
    expect(find.textContaining('原：边陲小城外常有过路旅人'), findsOneWidget);
    expect(find.textContaining('新增设定：渡口'), findsOneWidget);

    // Untick the new entry, keep the rewritten one.
    await tester.tap(find.byType(AppSwitch).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入选中的 1 条'));
    await tester.pumpAndSettle();

    final saved = await repo.open('proj_rain_night');
    expect(saved.worldBook.entries.any((e) => e.title == '渡口'), isFalse);
    expect(
      saved.worldBook.entries.firstWhere((e) => e.id == 'bg_world').body,
      '边陲小城常年下雨。',
    );
  });

  testWidgets('reads the graph before proposing a patch', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
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
    await settings.updateAi(settings.ai.copyWith(text: _endpoint));

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        settings: settings,
        textClient: _ScriptedTextClient([
          const _Reply.tool('main.read_graph'),
          const _Reply.tool('main.patch', {
            'ops': [
              {'op': 'set_summary', 'summary': '雨夜出城，天亮前必须走脱'},
            ],
          }),
          const _Reply.text(''),
        ]),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 640,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '概括改短');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('这次要改这些'), findsOneWidget);
    expect(find.textContaining('修改主线概括'), findsOneWidget);
    expect(find.textContaining('改：雨夜出城，天亮前必须走脱'), findsOneWidget);

    await tester.tap(find.text('写入选中的 1 条'));
    await tester.pumpAndSettle();

    final saved = await repo.open('proj_rain_night');
    expect(saved.main.summary, '雨夜出城，天亮前必须走脱');
    expect(saved.main.nodes, isNotEmpty);
  });

  testWidgets('writes every layer from one merged review sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
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
    await settings.updateAi(settings.ai.copyWith(text: _endpoint));

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        settings: settings,
        textClient: _ScriptedTextClient([
          const _Reply.tool('world.patch', {
            'ops': [
              {'op': 'upsert_entry', 'title': '渡口', 'body': '夜里停摆。'},
            ],
          }),
          const _Reply.tool('cast.patch', {
            'ops': [
              {'op': 'upsert_member', 'name': '船夫', 'summary': '摆渡人'},
            ],
          }),
          const _Reply.text(''),
        ]),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 640,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '补一个渡口，再加个船夫');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('这次要改这些'), findsOneWidget);
    // Both layers sit in the same sheet, under their own headers. The second
    // row can start below the fold, so scroll it into view first.
    expect(find.text('世界书'), findsWidgets);
    expect(find.textContaining('新增设定：渡口'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('新增角色：船夫'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(AppSheetScrollBody),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('新增角色：船夫'), findsOneWidget);

    await tester.tap(find.text('写入选中的 2 条'));
    await tester.pumpAndSettle();

    final saved = await repo.open('proj_rain_night');
    expect(saved.worldBook.entries.any((e) => e.title == '渡口'), isTrue);
    expect(saved.cast.any((c) => c.name == '船夫'), isTrue);
    expect(find.text('写好了，世界书、角色一起更新了'), findsOneWidget);
  });

  testWidgets('asks for a story before calling the model', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDraft(
        projectId: null,
        projectTitle: '',
        composer: '',
        lines: [],
      ),
    );

    await tester.pumpWidget(
      testScoped(
        textClient: _ScriptedTextClient(const []),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 640,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '今晚必须出城');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('先在上面选一个故事，我才能读它的设定'), findsOneWidget);
  });

  testWidgets('sends the earlier conversation back with each turn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
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
        lines: [
          CreateAssistantDraftLine(role: 'user', text: '林晚现在什么语气'),
          CreateAssistantDraftLine(role: 'assistant', text: '偏温和，像在哄人'),
        ],
      ),
    );
    final settings = testSettingsController();
    await settings.updateAi(settings.ai.copyWith(text: _endpoint));
    final client = _ScriptedTextClient([_Reply.text('好，改成更冷')]);

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        settings: settings,
        textClient: client,
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 640,
            child: CreateAssistantPanel(draftStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '再冷一点');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    final sent = client.lastMessages.map((m) => m.content).toList();
    expect(sent, contains('林晚现在什么语气'));
    expect(sent, contains('偏温和，像在哄人'));
    expect(sent.last, '再冷一点');
  });

  testWidgets('follows the story whose edit page just opened', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = MemoryProjectRepository(
      seed: {
        'proj_rain_night': const ProjectFactory().createRainNightSample(),
        'proj_mountain': const ProjectFactory().createRainNightSample(
          id: 'proj_mountain',
          title: '山中来信',
        ),
      },
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
    final assistant = CreateAssistantController();

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        textClient: _ScriptedTextClient(const []),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 640,
            child: CreateAssistantPanel(
              draftStore: store,
              controller: assistant,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('雨夜投宿'), findsOneWidget);

    // The story hub is open; opening its plot graph (same story) keeps it.
    final hub = Object();
    final graph = Object();
    assistant.enterStory(hub, 'proj_rain_night');
    await tester.pumpAndSettle();
    expect(find.text('雨夜投宿'), findsOneWidget);

    // Another story's edit page moves the assistant with it.
    assistant.enterStory(graph, 'proj_mountain');
    await tester.pumpAndSettle();
    expect(find.text('山中来信'), findsOneWidget);
    expect(find.text('雨夜投宿'), findsNothing);

    // Closing that page hands the assistant back to the page underneath.
    assistant.leaveStory(graph);
    await tester.pumpAndSettle();
    expect(find.text('雨夜投宿'), findsOneWidget);

    // A manual pick is kept: no page changed, so nothing overrides it.
    await tester.tap(find.byType(AppSelectField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('山中来信').last);
    await tester.pumpAndSettle();
    expect(find.text('山中来信'), findsOneWidget);
    expect(find.text('雨夜投宿'), findsNothing);
  });
}
