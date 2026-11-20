import 'package:anoworld/domain/main/apply_main_graph_patch.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const applier = ApplyMainGraphPatch();

  MainStory base() => MainStory(
        summary: '旧概括',
        startNodeId: 'n1',
        nodes: [
          StoryNode(
            id: 'n1',
            title: '开场',
            synopsis: '开始',
            beatIds: const [],
            tags: StoryNodeKind.apply(const [], StoryNodeKind.opening),
          ),
          StoryNode(
            id: 'n2',
            title: '中途',
            synopsis: '继续',
            beatIds: const [],
            tags: StoryNodeKind.apply(const [], StoryNodeKind.scene),
          ),
        ],
        edges: const [
          StoryEdge(
            id: 'e1',
            from: 'n1',
            to: 'n2',
            kind: EdgeKind.defaultEdge,
          ),
        ],
        beats: const [],
      );

  test('upserts node and edge', () {
    final next = applier.apply(base(), [
      {
        'op': 'upsert_node',
        'title': '岔路',
        'synopsis': '另一条线',
      },
      {
        'op': 'upsert_edge',
        'from': 'n1',
        'to': '岔路',
        'kind': 'branch',
        'label': '走人',
      },
      {'op': 'set_summary', 'summary': '新概括'},
    ]);
    expect(next.summary, '新概括');
    expect(next.nodes.length, 3);
    expect(next.edges.any((e) => e.kind == EdgeKind.branch), isTrue);
  });

  test('remove_node drops edges and retargets start', () {
    final next = applier.apply(base(), [
      {'op': 'remove_node', 'id': 'n1'},
    ]);
    expect(next.nodes.map((n) => n.id), ['n2']);
    expect(next.edges, isEmpty);
    expect(next.startNodeId, 'n2');
  });
}
