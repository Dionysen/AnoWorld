import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/main_runtime.dart';
import 'package:anoworld/domain/runtime/play_pointer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blank project starts in needsBridge', () {
    final blank = const ProjectFactory().createBlank(
      id: 'p',
      title: 't',
      now: DateTime.utc(2026, 1, 1),
    );
    final runtime = MainRuntime(blank.main);
    expect(runtime.needsBridge, isTrue);
    expect(runtime.currentNode?.title, '开场');
    expect(blank.main.beats, isEmpty);
  });

  test('ensurePlayableMain injects opening when nodes empty', () {
    const empty = MainStory(
      summary: '',
      startNodeId: '',
      nodes: [],
      edges: [],
      beats: [],
    );
    final playable = ProjectFactory.ensurePlayableMain(empty);
    expect(playable.nodes, hasLength(1));
    expect(MainRuntime(playable).needsBridge, isTrue);
  });

  test('ensurePlayableMain strips legacy blank end-only placeholder', () {
    const legacy = MainStory(
      summary: '',
      startNodeId: 'n_start',
      nodes: [
        StoryNode(
          id: 'n_start',
          title: '开场',
          beatIds: ['b_start'],
          tags: ['opening'],
        ),
      ],
      edges: [],
      beats: [
        Beat(
          id: 'b_start',
          nodeId: 'n_start',
          scene: Scene(),
          appearances: [],
          lines: [
            DialogueLine(
              id: 'l_placeholder',
              text: '（在这里开始故事）',
              kind: DialogueKind.narration,
            ),
          ],
          choices: [
            Choice(
              id: 'ch_end',
              text: '结束',
              target: Transition(type: TransitionType.end),
            ),
          ],
        ),
      ],
    );
    final playable = ProjectFactory.ensurePlayableMain(legacy);
    expect(playable.beats, isEmpty);
    expect(playable.nodes.single.beatIds, isEmpty);
    expect(MainRuntime(playable).needsBridge, isTrue);
  });

  test('stay choice requests another bridge beat', () {
    const main = MainStory(
      summary: '开放',
      startNodeId: 'n1',
      nodes: [
        StoryNode(id: 'n1', title: '开场', beatIds: []),
      ],
      edges: [],
      beats: [],
    );
    final runtime = MainRuntime(main);
    runtime.adoptBridgeBeat(
      const Beat(
        id: 'b_gen',
        nodeId: 'n1',
        scene: Scene(),
        appearances: [],
        lines: [
          DialogueLine(id: 'l1', text: '风起了。', kind: DialogueKind.narration),
        ],
        choices: [
          Choice(
            id: 'c_stay',
            text: '继续',
            target: Transition(
              type: TransitionType.beat,
              beatId: kBridgeStayBeatId,
            ),
          ),
        ],
      ),
    );
    runtime.advance();
    expect(runtime.pointer.phase, PlayPhase.choices);
    runtime.choose('c_stay');
    expect(runtime.needsBridge, isTrue);
  });

  test('open interval with no choices after lines requests bridge', () {
    const main = MainStory(
      summary: '开放',
      startNodeId: 'n1',
      nodes: [
        StoryNode(id: 'n1', title: '开场', beatIds: ['b1']),
      ],
      edges: [],
      beats: [
        Beat(
          id: 'b1',
          nodeId: 'n1',
          scene: Scene(),
          appearances: [],
          lines: [
            DialogueLine(id: 'l1', text: '……', kind: DialogueKind.narration),
          ],
          choices: [],
        ),
      ],
    );
    final runtime = MainRuntime(main);
    runtime.advance();
    expect(runtime.needsBridge, isTrue);
  });

  test('empty start node requests bridge', () {
    const main = MainStory(
      summary: '骨架',
      startNodeId: 'n1',
      nodes: [
        StoryNode(
          id: 'n1',
          title: '开场',
          synopsis: '开始',
          beatIds: [],
          layout: NodeLayout(x: 0, y: 0),
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
    );
    final runtime = MainRuntime(main);
    expect(runtime.needsBridge, isTrue);
    expect(runtime.pointer.phase, PlayPhase.needsBridge);
  });

  test('jumpToNode reaches ending and ends', () {
    const main = MainStory(
      summary: '骨架',
      startNodeId: 'n1',
      nodes: [
        StoryNode(id: 'n1', title: '开场', synopsis: '开始', beatIds: []),
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
    );
    final runtime = MainRuntime(main);
    runtime.jumpToNode('n2');
    expect(runtime.pointer.isEnded, isTrue);
  });

  test('adoptBridgeBeat enters generated lines', () {
    const main = MainStory(
      summary: '骨架',
      startNodeId: 'n1',
      nodes: [
        StoryNode(id: 'n1', title: '开场', synopsis: '开始', beatIds: []),
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
    );
    final runtime = MainRuntime(main);
    runtime.adoptBridgeBeat(
      const Beat(
        id: 'b_gen',
        nodeId: 'n1',
        scene: Scene(locationText: '城门'),
        appearances: [],
        lines: [
          DialogueLine(id: 'l1', text: '该走了。', kind: DialogueKind.narration),
        ],
        choices: [
          Choice(
            id: 'c1',
            text: '前往结局',
            target: Transition(type: TransitionType.node, nodeId: 'n2'),
          ),
        ],
      ),
    );
    expect(runtime.pointer.phase, PlayPhase.lines);
    expect(runtime.currentLine?.text, '该走了。');
    runtime.advance();
    expect(runtime.pointer.phase, PlayPhase.choices);
    runtime.choose('c1');
    expect(runtime.pointer.isEnded, isTrue);
  });
}
