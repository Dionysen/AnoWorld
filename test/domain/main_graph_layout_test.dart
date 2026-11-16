import 'package:anoworld/domain/main/main_graph_layout.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:flutter_test/flutter_test.dart';

MainStory _story({
  required String start,
  required List<StoryNode> nodes,
  required List<StoryEdge> edges,
}) {
  return MainStory(
    summary: 't',
    startNodeId: start,
    nodes: nodes,
    edges: edges,
    beats: const [],
  );
}

StoryNode _n(String id, {double? x, double? y}) => StoryNode(
      id: id,
      title: id,
      beatIds: const [],
      layout: x == null || y == null ? null : NodeLayout(x: x, y: y),
    );

StoryEdge _e(String id, String from, String to) => StoryEdge(
      id: id,
      from: from,
      to: to,
      kind: EdgeKind.defaultEdge,
    );

void main() {
  test('linear chain goes left to right', () {
    final main = _story(
      start: 'a',
      nodes: [_n('a', x: 9, y: 9), _n('b', x: 1, y: 1), _n('c', x: 2, y: 2)],
      edges: [_e('e1', 'a', 'b'), _e('e2', 'b', 'c')],
    );
    final next = MainGraphLayout.arrange(
      main,
      widths: const {'a': 100, 'b': 100, 'c': 100},
      heights: const {'a': 80, 'b': 80, 'c': 80},
      gapX: 40,
      gapY: 20,
      originX: 10,
      originY: 10,
    );
    expect(next.nodeById('a')!.layout!.x, 10);
    expect(next.nodeById('b')!.layout!.x, 10 + 100 + 40);
    expect(next.nodeById('c')!.layout!.x, 10 + 2 * (100 + 40));
    expect(next.nodeById('a')!.layout!.y, 10);
    expect(next.nodeById('b')!.layout!.y, 10);
    expect(next.nodeById('c')!.layout!.y, 10);
  });

  test('fork stacks siblings in the same layer', () {
    final main = _story(
      start: 'a',
      nodes: [
        _n('a', x: 0, y: 0),
        _n('b', x: 0, y: 50),
        _n('c', x: 0, y: 10),
      ],
      edges: [_e('e1', 'a', 'b'), _e('e2', 'a', 'c')],
    );
    final next = MainGraphLayout.arrange(
      main,
      widths: const {'a': 100, 'b': 100, 'c': 100},
      heights: const {'a': 40, 'b': 40, 'c': 40},
      gapX: 30,
      gapY: 10,
      originX: 0,
      originY: 0,
    );
    expect(next.nodeById('a')!.layout!.x, 0);
    expect(next.nodeById('b')!.layout!.x, 130);
    expect(next.nodeById('c')!.layout!.x, 130);
    // Stable by previous y: c(y=10) then b(y=50)
    expect(next.nodeById('c')!.layout!.y, lessThan(next.nodeById('b')!.layout!.y));
  });

  test('merge places shared target in a later layer', () {
    final main = _story(
      start: 'a',
      nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
      edges: [
        _e('e1', 'a', 'b'),
        _e('e2', 'a', 'c'),
        _e('e3', 'b', 'd'),
        _e('e4', 'c', 'd'),
      ],
    );
    final next = MainGraphLayout.arrange(main);
    expect(next.nodeById('a')!.layout!.x, lessThan(next.nodeById('b')!.layout!.x));
    expect(next.nodeById('b')!.layout!.x, next.nodeById('c')!.layout!.x);
    expect(next.nodeById('d')!.layout!.x, greaterThan(next.nodeById('b')!.layout!.x));
  });

  test('unreachable nodes sit after the deepest reachable column', () {
    final main = _story(
      start: 'a',
      nodes: [_n('a'), _n('b'), _n('orphan', x: 0, y: 0)],
      edges: [_e('e1', 'a', 'b')],
    );
    final next = MainGraphLayout.arrange(
      main,
      widths: const {'a': 50, 'b': 50, 'orphan': 50},
      heights: const {'a': 40, 'b': 40, 'orphan': 40},
      gapX: 20,
      originX: 0,
      originY: 0,
    );
    expect(
      next.nodeById('orphan')!.layout!.x,
      greaterThan(next.nodeById('b')!.layout!.x),
    );
  });
}
