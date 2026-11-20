import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/chat/tavern_chat_generate_action.dart';
import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/chat/tavern_reply_choice_action.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.replies, {this.reasoning});

  final List<String> replies;
  final String? reasoning;
  int calls = 0;
  final users = <String>[];
  final systems = <String>[];

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    users.add(user);
    systems.add(system);
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return AiTextCompletion(
      content: replies[calls++],
      reasoning: reasoning,
    );
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

  test('tavern generate returns assistant prose and asks not to speak as user',
      () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _ScriptedTextClient(['夜风很轻。']);
    final action = TavernChatGenerateAction(textClient: client);
    final out = await action.generate(
      ctx: ctx(),
      project: project,
      history: const [],
    );
    expect(out.content, '夜风很轻。');
    expect(out.reasoning, isNull);
    expect(client.users.single, contains('尚无对话'));
    expect(client.users.single, contains('助手这一轮'));
  });

  test('tavern generate keeps reasoning from completion', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _ScriptedTextClient(
      ['夜风很轻。'],
      reasoning: '先写气氛',
    );
    final action = TavernChatGenerateAction(textClient: client);
    final out = await action.generate(
      ctx: ctx(),
      project: project,
      history: const [],
    );
    expect(out.content, '夜风很轻。');
    expect(out.reasoning, '先写气氛');
  });

  test('tavern generate includes prior turns', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _ScriptedTextClient(['好的。']);
    final action = TavernChatGenerateAction(textClient: client);
    await action.generate(
      ctx: ctx(),
      project: project,
      history: const [
        TavernChatMessage(
          id: 'a1',
          role: TavernChatRole.assistant,
          content: '你好',
        ),
        TavernChatMessage(
          id: 'u1',
          role: TavernChatRole.user,
          content: '在吗',
        ),
      ],
    );
    expect(client.users.single, contains('你好'));
    expect(client.users.single, contains('在吗'));
  });

  test('chat injects only the lore the scene brings up', () async {
    final project = Project(
      meta: ProjectMeta(
        id: 'p',
        title: '测试故事',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      worldBook: const WorldBook(
        entries: <WorldBookEntry>[
          WorldBookEntry(
            id: 'w_rule',
            title: '基调',
            body: '常年阴雨。',
            alwaysOn: true,
          ),
          WorldBookEntry(
            id: 'w_ferry',
            title: '渡口',
            body: '渡口入夜停摆。',
            keys: <String>['渡口'],
          ),
          WorldBookEntry(
            id: 'w_palace',
            title: '王城',
            body: '王城在千里之外。',
            keys: <String>['王城'],
          ),
        ],
      ),
      cast: const <CastMember>[],
      main: const MainStory(
        summary: '',
        startNodeId: '',
        nodes: <StoryNode>[],
        edges: <StoryEdge>[],
        beats: <Beat>[],
      ),
    );
    final client = _ScriptedTextClient(['船夫摇头。']);
    await TavernChatGenerateAction(textClient: client).generate(
      ctx: ctx(),
      project: project,
      history: const [
        TavernChatMessage(
          id: 'u1',
          role: TavernChatRole.user,
          content: '渡口还有船吗',
        ),
      ],
    );

    final system = client.systems.single;
    expect(system, contains('常年阴雨'));
    expect(system, contains('渡口入夜停摆'));
    expect(system, isNot(contains('王城在千里之外')));
    // 正文里不再重复整本世界书。
    expect(client.users.single, isNot(contains('王城在千里之外')));
  });

  test('reply choices parse JSON choices array', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _ScriptedTextClient([
      '{"choices":["走近一点","先问问她","转身离开"]}',
    ]);
    final action = TavernReplyChoiceAction(textClient: client);
    final choices = await action.generate(
      ctx: ctx(),
      project: project,
      history: const [
        TavernChatMessage(
          id: 'a1',
          role: TavernChatRole.assistant,
          content: '她看着你',
        ),
      ],
    );
    expect(choices, ['走近一点', '先问问她', '转身离开']);
  });
}
