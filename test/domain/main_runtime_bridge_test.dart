import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/main_runtime.dart';
import 'package:anoworld/domain/runtime/play_pointer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
