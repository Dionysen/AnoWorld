import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_port_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('display truncates after 15 characters', () {
    expect(GraphPortTitle.display('继续'), '继续');
    expect(
      GraphPortTitle.display('一二三四五六七八九十一二三四五六'),
      '一二三四五六七八九十一二三四五…',
    );
    expect(
      GraphPortTitle.display('一二三四五六七八九十一二三四五'),
      '一二三四五六七八九十一二三四五',
    );
  });

  test('empty pending and wired fallbacks', () {
    expect(GraphPortTitle.display(null, pending: true), '添加');
    expect(GraphPortTitle.display('', pending: false), '未命名');
  });

  test('node width grows with longer port titles', () {
    const short = GraphNodeData(
      id: 'a',
      label: 'A',
      x: 0,
      y: 0,
      inputLabel: '进入',
      outputs: [
        GraphOutputPort(id: 'e1', label: '继续'),
        GraphOutputPort.pendingPort,
      ],
    );
    const long = GraphNodeData(
      id: 'b',
      label: 'B',
      x: 0,
      y: 0,
      inputLabel: '进入',
      outputs: [
        GraphOutputPort(
          id: 'e1',
          label: '一二三四五六七八九十一二三四五六七八',
        ),
        GraphOutputPort.pendingPort,
      ],
    );
    expect(long.resolvedWidth, greaterThan(short.resolvedWidth));
    expect(long.resolvedWidth, lessThanOrEqualTo(GraphPortTitle.maxNodeWidth));
    expect(short.resolvedWidth, greaterThanOrEqualTo(GraphPortTitle.minNodeWidth));
  });

  test('explicit width overrides auto size', () {
    const node = GraphNodeData(
      id: 'a',
      label: 'A',
      x: 0,
      y: 0,
      width: 220,
      outputs: [GraphOutputPort(id: 'e1', label: '继续')],
    );
    expect(node.resolvedWidth, 220);
  });
}
