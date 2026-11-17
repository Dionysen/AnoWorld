import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/staged_create_actions.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.replies);

  final List<String> replies;
  int calls = 0;
  final users = <String>[];

  @override
  Future<String> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    users.add(user);
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return replies[calls++];
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

  test('generateWorld maps and applyWorld only changes background', () async {
    final client = _ScriptedTextClient([
      '{"sections":[{"title":"世界观","body":"雨夜边城"}]}',
    ]);
    final actions = StagedCreateActions(textClient: client);
    final background = await actions.generateWorld(
      ctx: ctx(),
      prompt: '雨夜边城',
    );
    expect(background.entries.first.body, '雨夜边城');

    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final next = actions.applyWorld(blank, background);
    expect(next.background.entries.first.body, '雨夜边城');
    expect(next.cast, blank.cast);
    expect(next.main.startNodeId, blank.main.startNodeId);
  });

  test('retries once when first payload is not json', () async {
    final client = _ScriptedTextClient([
      'not json',
      '{"sections":[{"title":"世界观","body":"修好了"}]}',
    ]);
    final actions = StagedCreateActions(textClient: client);
    final background = await actions.generateWorld(
      ctx: ctx(),
      prompt: '提示',
    );
    expect(background.entries.first.body, '修好了');
    expect(client.calls, 2);
    expect(client.users.last, contains('只输出合法 JSON'));
  });

  test('generateMain builds skeleton without beats', () async {
    final client = _ScriptedTextClient([
      '''
{"summary":"短主线","stations":[
{"title":"城门","synopsis":"离开","exits":[{"to":"客栈","kind":"default"},{"to":"荒野","kind":"branch"}]},
{"title":"客栈","synopsis":"投宿","exits":[{"to":"end","kind":"default"}]},
{"title":"荒野","synopsis":"独行","exits":[{"to":"end","kind":"default"}]}
]}
''',
    ]);
    final actions = StagedCreateActions(textClient: client);
    final cast = const [
      CastMember(id: 'c_0', name: '少年'),
      CastMember(id: 'c_1', name: '掌柜'),
    ];
    final main = await actions.generateMain(
      ctx: ctx(),
      prompt: '出城',
      background: const Background(
        entries: [
          BackgroundEntry(
            id: 'bg',
            title: '世界',
            body: '边城',
            alwaysOn: true,
          ),
        ],
      ),
      cast: cast,
    );
    expect(main.beats, isEmpty);
    expect(main.nodes.length, greaterThanOrEqualTo(3));
    expect(main.edges, isNotEmpty);
  });

  test('applyCast does not wipe main', () {
    final sample = const ProjectFactory().createRainNightSample();
    final actions = StagedCreateActions(
      textClient: _ScriptedTextClient(const []),
    );
    final next = actions.applyCast(
      sample,
      const [CastMember(id: 'c_new', name: '新人')],
    );
    expect(next.cast.single.name, '新人');
    expect(next.main.summary, sample.main.summary);
  });
}
