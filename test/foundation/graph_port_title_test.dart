import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_port_title.dart';
import 'package:flutter_test/flutter_test.dart';

const _unnamed = 'Untitled';
const _add = 'Add';

String _display(String? label, {bool pending = false}) {
  return GraphPortTitle.display(
    label,
    pending: pending,
    emptyWired: _unnamed,
    emptyPending: _add,
  );
}

void main() {
  test('display truncates after 15 characters', () {
    expect(_display('继续'), '继续');
    expect(
      _display('一二三四五六七八九十一二三四五六'),
      '一二三四五六七八九十一二三四五…',
    );
    expect(
      _display('一二三四五六七八九十一二三四五'),
      '一二三四五六七八九十一二三四五',
    );
  });

  test('empty pending and wired fallbacks', () {
    expect(_display(null, pending: true), _add);
    expect(_display('', pending: false), _unnamed);
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
