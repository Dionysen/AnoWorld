import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.replies);

  final List<String> replies;
  int calls = 0;

  @override
  Future<String> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
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

  test('fallbackChoices point at legal outbound nodes', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final choices = BridgeGenerateAction.fallbackChoices(main, 'n1');
    expect(choices, isNotEmpty);
    expect(choices.first.target.type, TransitionType.node);
    expect(choices.first.target.nodeId, 'n2');
    expect(choices.first.text, contains('前往：'));
  });

  test('fallbackChoices without outs return continue and soft end', () {
    const main = MainStory(
      summary: 'x',
      startNodeId: 'n1',
      nodes: [
        StoryNode(id: 'n1', title: 'A', beatIds: []),
      ],
      edges: [],
      beats: [],
    );
    final choices = BridgeGenerateAction.fallbackChoices(main, 'n1');
    expect(choices, hasLength(2));
    expect(choices[0].text, '继续');
    expect(choices[0].target.type, TransitionType.beat);
    expect(choices[0].target.beatId, kBridgeStayBeatId);
    expect(choices[1].text, '告一段落');
    expect(choices[1].target.type, TransitionType.end);
  });

  test('open mode fills continue when choices empty', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _ScriptedTextClient([
      '{"location":"室内","lines":[{"speaker":"旁白","text":"风停了。"}],"choices":[]}',
    ]);
    final action = BridgeGenerateAction(textClient: client);
    final beat = await action.generate(
      ctx: ctx(),
      project: blank,
      nodeId: blank.main.startNodeId,
      session: BridgeSession(nodeId: blank.main.startNodeId),
    );
    expect(beat.lines.first.text, '风停了。');
    expect(beat.lines.first.kind, DialogueKind.narration);
    expect(beat.choices, hasLength(1));
    expect(beat.choices.single.text, '继续');
    expect(beat.choices.single.target.beatId, kBridgeStayBeatId);
  });

  test('speech lines keep plain text and map speakers', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final project = blank.copyWith(
      cast: const [
        CastMember(id: 'c1', name: '瑞希', summary: ''),
      ],
    );
    final client = _ScriptedTextClient([
      '''
{"lines":[
  {"speaker":"瑞希","text":"瑞希：你会更开心吗？"},
  {"speaker":"User","text":"会。"},
  {"speaker":"旁白","text":"夜还很长。"},
  {"speaker":"旁白","text":"瑞希：别急着躲。"}
],"choices":[]}''',
    ]);
    final action = BridgeGenerateAction(textClient: client);
    final beat = await action.generate(
      ctx: ctx(),
      project: project,
      nodeId: project.main.startNodeId,
      session: BridgeSession(nodeId: project.main.startNodeId),
      userAliases: const ['User'],
    );
    expect(beat.lines[0].text, '你会更开心吗？');
    expect(beat.lines[0].speakerId, 'c1');
    expect(beat.lines[0].kind, DialogueKind.speech);
    expect(beat.lines[1].text, '会。');
    expect(beat.lines[1].speakerId, kPlayUserSpeakerId);
    expect(beat.lines[2].kind, DialogueKind.narration);
    expect(beat.lines[2].speakerId, isNull);
    // speaker 误标旁白但正文带「瑞希：」时收回角色归属
    expect(beat.lines[3].text, '别急着躲。');
    expect(beat.lines[3].speakerId, 'c1');
    expect(beat.lines[3].kind, DialogueKind.speech);
  });

  test('generate drops illegal node targets and keeps legal ones', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final project = blank.copyWith(
      main: const MainStory(
        summary: '骨架',
        startNodeId: 'n1',
        nodes: [
          StoryNode(
            id: 'n1',
            title: '开场',
            synopsis: '出发',
            beatIds: [],
          ),
          StoryNode(
            id: 'n2',
            title: '结局',
            synopsis: '收束',
            beatIds: [],
            tags: ['ending'],
          ),
        ],
        edges: [
          StoryEdge(
            id: 'e1',
            from: 'n1',
            to: 'n2',
            kind: EdgeKind.defaultEdge,
          ),
        ],
        beats: [],
      ),
    );
    final client = _ScriptedTextClient([
      '''
{"location":"城门","lines":[{"speaker":"旁白","text":"雨还在下。"}],
 "choices":[
   {"text":"非法岔路","target":{"type":"node","nodeId":"ghost"}},
   {"text":"去结局","target":{"type":"node","nodeId":"n2"}}
 ]}''',
    ]);
    final action = BridgeGenerateAction(textClient: client);
    final beat = await action.generate(
      ctx: ctx(),
      project: project,
      nodeId: 'n1',
      session: const BridgeSession(nodeId: 'n1'),
    );
    expect(beat.lines.first.text, '雨还在下。');
    expect(beat.choices, hasLength(1));
    expect(beat.choices.first.target.nodeId, 'n2');
  });

  test('forceConverge retries when stay-only choices', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final project = blank.copyWith(
      main: const MainStory(
        summary: '骨架',
        startNodeId: 'n1',
        nodes: [
          StoryNode(id: 'n1', title: '开场', synopsis: '出发', beatIds: []),
          StoryNode(
            id: 'n2',
            title: '结局',
            beatIds: [],
            tags: ['ending'],
          ),
        ],
        edges: [
          StoryEdge(
            id: 'e1',
            from: 'n1',
            to: 'n2',
            kind: EdgeKind.defaultEdge,
          ),
        ],
        beats: [],
      ),
    );
    final client = _ScriptedTextClient([
      '{"lines":[{"text":"还在晃"}],"choices":[{"text":"再等等","target":{"type":"beat","beatId":"__stay__"}}]}',
      '{"lines":[{"text":"该走了"}],"choices":[{"text":"去结局","target":{"type":"node","nodeId":"n2"}}]}',
    ]);
    final action = BridgeGenerateAction(textClient: client);
    final beat = await action.generate(
      ctx: ctx(),
      project: project,
      nodeId: 'n1',
      session: const BridgeSession(
        nodeId: 'n1',
        turnCount: BridgeSession.defaultMaxBeats - 1,
      ),
    );
    expect(client.calls, 2);
    expect(beat.choices.single.target.type, TransitionType.node);
    expect(beat.choices.single.target.nodeId, 'n2');
  });
}
