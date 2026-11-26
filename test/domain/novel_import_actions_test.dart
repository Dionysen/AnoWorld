import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/novel_import_actions.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.replies);

  final List<String> replies;
  int calls = 0;
  final users = <String>[];

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    users.add(user);
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return AiTextCompletion(content: replies[calls++]);
  }
}

void main() {
  const endpoint = AiTextEndpoint(
    kind: AiTextProviderKind.openAiCompatible,
    baseUrl: 'http://localhost:8080/v1',
    apiKey: 'sk',
    model: 'demo',
  );

  AiPromptContext ctx() => AiPromptContext(
        endpoint: endpoint,
        generation: const GenerationPreset(),
        promptManager: PromptManagerConfig.defaultConfig(),
      );

  const mainJson = '''
{"summary":"雨夜主线","stations":[
{"title":"城门","synopsis":"赶到城门","exits":[{"to":"客栈","kind":"default"},{"to":"巷口","kind":"branch"}]},
{"title":"客栈","synopsis":"投宿打听","exits":[{"to":"黎明","kind":"default"}]},
{"title":"巷口","synopsis":"抄近路","exits":[{"to":"黎明","kind":"default"}]},
{"title":"黎明","synopsis":"离开边城","exits":[{"to":"end","kind":"default"}],"ending":true}
]}
''';

  List<String> pipelineReplies() => [
        '{"points":["少年赶路","雨夜边城"]}',
        '{"title":"雨夜投宿","summary":"少年雨夜入城","conflicts":["出城还是留下"]}',
        '{"sections":[{"title":"世界观","body":"雨夜边城靠传闻活着"}]}',
        '{"cast":[{"name":"少年","summary":"想离开的旅人","personality":"倔","speechStyle":"短句","exampleLines":["今晚必须走"]}]}',
        mainJson,
      ];

  test('runPipeline builds outline world cast main without stuffing full text into main',
      () async {
    final client = _ScriptedTextClient(pipelineReplies());
    final actions = NovelImportActions(
      textClient: client,
      minGraphStations: 4,
    );
    final steps = <NovelImportStep>[];
    final draft = await actions.runPipeline(
      ctx: ctx(),
      sourceText: '雨夜，少年赶到边城客栈。掌柜说城门半夜才开。',
      note: '主角第一人称',
      preferredTitle: '来自文件',
      onProgress: steps.add,
    );

    expect(steps, [
      NovelImportStep.outline,
      NovelImportStep.world,
      NovelImportStep.cast,
      NovelImportStep.main,
    ]);
    expect(draft.title, '来自文件');
    expect(draft.outline.title, '雨夜投宿');
    expect(draft.worldBook.entries, isNotEmpty);
    expect(draft.cast.first.name, '少年');
    expect(draft.main.nodes.length, greaterThanOrEqualTo(4));
    expect(draft.main.beats, isEmpty);
    expect(draft.hasSkeleton, isTrue);

    // Main prompt must not contain the long source dump as the only context;
    // staged main call should see outline / note, not raw body alone.
    final mainUser = client.users.last;
    expect(mainUser, contains('雨夜投宿'));
    expect(mainUser, contains('主角第一人称'));
  });

  test('commit writes project via repository', () async {
    final client = _ScriptedTextClient(pipelineReplies());
    final actions = NovelImportActions(
      textClient: client,
      minGraphStations: 4,
    );
    final draft = await actions.runPipeline(
      ctx: ctx(),
      sourceText: '一段足够短的正文用来导入。',
    );
    final projects = MemoryProjectRepository();
    final project = await actions.commit(projects: projects, draft: draft);
    expect(project.meta.title, isNotEmpty);
    expect(project.worldBook.entries, isNotEmpty);
    expect(project.cast, isNotEmpty);
    expect(project.main.nodes.length, greaterThanOrEqualTo(2));

    final opened = await projects.open(project.meta.id);
    expect(opened.meta.id, project.meta.id);
  });

  test('empty body throws before calling the model', () async {
    final client = _ScriptedTextClient([]);
    final actions = NovelImportActions(textClient: client);
    await expectLater(
      () => actions.runPipeline(ctx: ctx(), sourceText: '   '),
      throwsA(isA<AiTextException>()),
    );
    expect(client.calls, 0);
  });

  test('draft withoutStation drops edges and fixes start', () async {
    final client = _ScriptedTextClient(pipelineReplies());
    final actions = NovelImportActions(
      textClient: client,
      minGraphStations: 4,
    );
    final draft = await actions.runPipeline(
      ctx: ctx(),
      sourceText: '短正文。',
    );
    final dropId = draft.main.nodes[1].id;
    final next = draft.withoutStation(dropId);
    expect(next.main.nodes.any((n) => n.id == dropId), isFalse);
    expect(
      next.main.edges.any((e) => e.from == dropId || e.to == dropId),
      isFalse,
    );
    expect(
      next.main.nodes.any((n) => n.id == next.main.startNodeId),
      isTrue,
    );
  });
}
