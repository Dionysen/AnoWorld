import 'package:anoworld/domain/main/main_graph_ops.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ops = MainGraphOps();

  test('moveNode updates layout only', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final next = ops.moveNode(main, 'n1', const NodeLayout(x: 50, y: 60));
    expect(next.nodeById('n1')!.layout!.x, 50);
    expect(next.nodeById('n1')!.title, '城门');
  });

  test('removeNode cascades edges and beats', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final next = ops.removeNode(main, 'n1');
    expect(next.nodeById('n1'), isNull);
    expect(next.beatById('b1'), isNull);
    expect(next.edges.where((e) => e.from == 'n1' || e.to == 'n1'), isEmpty);
    expect(next.startNodeId, isNot('n1'));
  });

  test('addEdge appends connection', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final next = ops.addEdge(
      main,
      const StoryEdge(
        id: 'e_branch',
        from: 'n1',
        to: 'n2',
        kind: EdgeKind.branch,
        label: '岔路',
      ),
    );
    expect(next.edges.length, main.edges.length + 1);
  });

  test('updateNodeMeta writes title and synopsis', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final next = ops.updateNodeMeta(
      main,
      nodeId: 'n1',
      title: '城门外',
      synopsis: '必须离开',
    );
    expect(next.nodeById('n1')!.title, '城门外');
    expect(next.nodeById('n1')!.synopsis, '必须离开');
  });

  test('setNodeKind updates kind tag', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final next = ops.setNodeKind(main, 'n2', StoryNodeKind.ending);
    expect(StoryNodeKind.fromTags(next.nodeById('n2')!.tags), StoryNodeKind.ending);
    expect(next.nodeById('n2')!.tags, isNot(contains('turning')));
  });
}
