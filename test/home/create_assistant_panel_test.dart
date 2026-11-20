import 'dart:convert';

import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
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
  const _Reply.text(this.text)
      : tool = null,
        args = const <String, dynamic>{};

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

  testWidgets('writes a generated plot graph into the selected story', (
    tester,
  ) async {
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

    await tester.tap(find.text('替换情节图'));
    await tester.pumpAndSettle();

    final saved = await repo.open('proj_rain_night');
    expect(saved.main.nodes.length, greaterThanOrEqualTo(20));
    expect(saved.main.edges, isNotEmpty);
    expect(saved.main.beats, isEmpty);
    expect(
      find.text('情节图写好了，可以在情节图里继续调整'),
      findsOneWidget,
    );
  });

  testWidgets('writes only the ticked ops from the review sheet', (
    tester,
  ) async {
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

    await tester.tap(find.text('世界书'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      '世界观改冷一点，再加一个渡口',
    );
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('这次要改这些'), findsOneWidget);
    expect(
      find.textContaining('原：边陲小城外常有过路旅人'),
      findsOneWidget,
    );
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
}
