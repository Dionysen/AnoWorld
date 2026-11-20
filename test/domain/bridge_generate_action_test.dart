import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/world_book.dart';
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

/// Records the composed system prompt for assertions.
class _RecordingTextClient implements AiTextClient {
  _RecordingTextClient(this.reply, this.prompts);

  final String reply;
  final List<String> prompts;
  final users = <String>[];

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    prompts.add(system);
    users.add(user);
    return AiTextCompletion(content: reply);
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

  test('open mode keeps empty choices for tap-to-continue', () async {
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
      inStationChoiceFrequency: InStationChoiceFrequency.off,
    );
    expect(beat.lines.first.text, '风停了。');
    expect(beat.lines.first.kind, DialogueKind.narration);
    expect(beat.choices, isEmpty);
  });

  test('strips in-station choices when frequency disallows them', () {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final beat = BridgeGenerateAction.parseBeatJson(
      '{"lines":[{"speaker":"旁白","text":"一段"}],"choices":['
      '{"text":"继续","target":{"type":"beat","beatId":"$kBridgeStayBeatId"}}]}',
      project: blank,
      nodeId: blank.main.startNodeId,
      beatId: 'b1',
      legalNodeIds: const {},
      forceConverge: false,
      openMode: true,
      allowInStationChoices: false,
    );
    expect(beat.choices, isEmpty);
  });

  test('minLines retries a short reply once', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _ScriptedTextClient([
      '{"lines":[{"speaker":"旁白","text":"只有一句。"}],"choices":[]}',
      '{"lines":[{"speaker":"旁白","text":"一。"},'
          '{"speaker":"旁白","text":"二。"},'
          '{"speaker":"旁白","text":"三。"}],"choices":[]}',
    ]);
    final action = BridgeGenerateAction(textClient: client);
    final beat = await action.generate(
      ctx: ctx(),
      project: blank,
      nodeId: blank.main.startNodeId,
      session: BridgeSession(nodeId: blank.main.startNodeId),
      minLines: 3,
    );
    expect(client.calls, 2);
    expect(beat.lines, hasLength(3));
  });

  test('minLines keeps the last short reply when retries run out', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _ScriptedTextClient([
      '{"lines":[{"speaker":"旁白","text":"短一。"}],"choices":[]}',
      '{"lines":[{"speaker":"旁白","text":"短二。"}],"choices":[]}',
    ]);
    final action = BridgeGenerateAction(textClient: client);
    final beat = await action.generate(
      ctx: ctx(),
      project: blank,
      nodeId: blank.main.startNodeId,
      session: BridgeSession(nodeId: blank.main.startNodeId),
      minLines: 3,
    );
    expect(client.calls, 2);
    expect(beat.lines.single.text, '短二。');
  });

  test('minLines appears in the task prompt', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final prompts = <String>[];
    final client = _RecordingTextClient(
      '{"lines":[{"speaker":"旁白","text":"一。"}],"choices":[]}',
      prompts,
    );
    final action = BridgeGenerateAction(textClient: client);
    await action.generate(
      ctx: ctx(),
      project: blank,
      nodeId: blank.main.startNodeId,
      session: BridgeSession(nodeId: blank.main.startNodeId),
      minLines: 4,
    );
    expect(prompts.first, contains('至少 4 句'));
    expect(prompts.first, isNot(contains('至少 1 句')));
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

  test('bridge injects hit lore and keeps the whole book out', () async {
    final project = const ProjectFactory().createRainNightSample().copyWith(
      worldBook: const WorldBook(
        entries: <WorldBookEntry>[
          WorldBookEntry(
            id: 'w_rule',
            title: '基调',
            body: '常年阴雨。',
            alwaysOn: true,
          ),
          WorldBookEntry(
            id: 'w_inn',
            title: '客栈',
            body: '客栈只在夜里开门。',
            keys: <String>['客栈'],
          ),
          WorldBookEntry(
            id: 'w_palace',
            title: '王城',
            body: '王城在千里之外。',
            keys: <String>['王城'],
          ),
        ],
      ),
    );
    final prompts = <String>[];
    final client = _RecordingTextClient(
      '{"lines":[{"speaker":"旁白","text":"一。"}],"choices":[]}',
      prompts,
    );
    final start = project.main.startNodeId;
    await BridgeGenerateAction(textClient: client).generate(
      ctx: ctx(),
      project: project,
      nodeId: start,
      session: BridgeSession(nodeId: start, summary: '主角推开客栈的门'),
    );

    final system = prompts.single;
    expect(system, contains('常年阴雨'));
    expect(system, contains('客栈只在夜里开门'));
    expect(system, isNot(contains('王城在千里之外')));
    // 整本世界书不再重复塞进正文。
    expect(client.users.single, isNot(contains('设定摘要')));
    expect(client.users.single, isNot(contains('王城在千里之外')));
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
      inStationChoiceFrequency: InStationChoiceFrequency.often,
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

  test('parseBeatJson caps choices at maxChoicesPerBeat', () {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final beat = BridgeGenerateAction.parseBeatJson(
      '''{"lines":[{"speaker":"旁白","text":"多选项"}],"choices":[
        {"text":"一","target":{"type":"end"}},
        {"text":"二","target":{"type":"end"}},
        {"text":"三","target":{"type":"beat","beatId":"$kBridgeStayBeatId"}},
        {"text":"四","target":{"type":"end"}},
        {"text":"五","target":{"type":"end"}}
      ]}''',
      project: blank,
      nodeId: blank.main.startNodeId,
      beatId: 'bridge_x_1',
      legalNodeIds: const {},
      forceConverge: false,
      openMode: true,
    );
    expect(beat.choices, hasLength(BridgeSession.maxChoicesPerBeat));
    expect(
      beat.choices.any((c) => c.target.beatId == kBridgeStayBeatId),
      isTrue,
    );
  });

  test('capChoices prefers stay then node over end', () {
    final capped = BridgeGenerateAction.capChoices([
      const Choice(
        id: 'e1',
        text: '结束1',
        target: Transition(type: TransitionType.end),
      ),
      const Choice(
        id: 'e2',
        text: '结束2',
        target: Transition(type: TransitionType.end),
      ),
      Choice(
        id: 's',
        text: '继续',
        target: Transition.toBeat(kBridgeStayBeatId),
      ),
      Choice(
        id: 'n',
        text: '去站',
        target: Transition.toNode('n2'),
      ),
      const Choice(
        id: 'e3',
        text: '结束3',
        target: Transition(type: TransitionType.end),
      ),
    ]);
    expect(capped, hasLength(3));
    expect(capped[0].id, 's');
    expect(capped[1].id, 'n');
    expect(capped[2].id, 'e1');
  });
}
