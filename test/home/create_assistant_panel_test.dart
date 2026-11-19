import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.replies);

  final List<String> replies;
  int calls = 0;

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return AiTextCompletion(content: replies[calls++]);
  }
}

const _graphJson = '''
{"summary":"少年在雨夜做出选择","stations":[
{"title":"城门","synopsis":"少年被拦下","exits":[{"to":"客栈","kind":"default"},{"to":"荒野","kind":"branch","label":"硬闯"}]},
{"title":"客栈","synopsis":"掌柜透露出路","exits":[{"to":"end","kind":"default"}]},
{"title":"荒野","synopsis":"独行遇雨","exits":[{"to":"end","kind":"default"}]}
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
        textClient: _ScriptedTextClient([_graphJson]),
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

    await tester.enterText(find.byType(TextField), '今晚必须出城');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('生成的情节'), findsOneWidget);
    expect(find.textContaining('处岔路'), findsWidgets);

    await tester.tap(find.text('替换情节图'));
    await tester.pumpAndSettle();

    final saved = await repo.open('proj_rain_night');
    expect(saved.main.nodes.length, greaterThanOrEqualTo(3));
    expect(saved.main.edges, isNotEmpty);
    expect(saved.main.beats, isEmpty);
    expect(
      find.text('情节图写好了，可以在情节图里继续调整'),
      findsOneWidget,
    );
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
