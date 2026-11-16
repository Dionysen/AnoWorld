import 'dart:ui';

import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ports sit on first content row under header', () {
    const node = GraphNodeData(
      id: 'a',
      label: 'A',
      x: 10,
      y: 20,
      width: 100,
      outputs: [GraphOutputPort.pendingPort],
    );
    final out = GraphEdgeGeometry.outputPort(node);
    final input = GraphEdgeGeometry.inputPort(node);
    expect(out.dx, 10 + node.resolvedWidth);
    expect(input.dx, 10);
    expect(out.dy, input.dy);
    expect(
      out.dy,
      20 +
          GraphEdgeGeometry.outputPortLocalY(
            index: 0,
            count: 1,
            headerSubtitle: false,
          ),
    );
  });

  test('header subtitle raises port rows', () {
    const plain = GraphNodeData(
      id: 'a',
      label: 'A',
      x: 0,
      y: 0,
      outputs: [GraphOutputPort.pendingPort],
    );
    const withSub = GraphNodeData(
      id: 'b',
      label: 'B',
      subtitle: 'detail',
      x: 0,
      y: 0,
      outputs: [GraphOutputPort.pendingPort],
    );
    expect(
      GraphEdgeGeometry.inputPort(withSub).dy,
      greaterThan(GraphEdgeGeometry.inputPort(plain).dy),
    );
  });

  test('multiple outputs stack vertically', () {
    const node = GraphNodeData(
      id: 'a',
      label: 'A',
      x: 0,
      y: 0,
      width: 100,
      outputs: [
        GraphOutputPort(id: 'e1'),
        GraphOutputPort(id: 'e2'),
        GraphOutputPort.pendingPort,
      ],
    );
    final a = GraphEdgeGeometry.outputPort(node, portId: 'e1');
    final b = GraphEdgeGeometry.outputPort(node, portId: 'e2');
    final c = GraphEdgeGeometry.outputPort(
      node,
      portId: GraphOutputPort.pendingId,
    );
    expect(a.dy, lessThan(b.dy));
    expect(b.dy, lessThan(c.dy));
    expect(a.dx, 100);
  });

  test('height grows with output count', () {
    final one = GraphEdgeGeometry.heightForOutputCount(1);
    final three = GraphEdgeGeometry.heightForOutputCount(3);
    expect(three, greaterThan(one));
    expect(
      GraphEdgeGeometry.outputPortLocalY(index: 0, count: 3),
      lessThan(
        GraphEdgeGeometry.outputPortLocalY(index: 2, count: 3),
      ),
    );
  });

  test('hitTestEdge finds nearest wire', () {
    const from = GraphNodeData(
      id: 'a',
      label: 'A',
      x: 0,
      y: 0,
      width: 100,
      height: 80,
      outputs: [GraphOutputPort(id: 'e1')],
    );
    const to = GraphNodeData(
      id: 'b',
      label: 'B',
      x: 220,
      y: 0,
      width: 100,
      height: 80,
    );
    final a = GraphEdgeGeometry.outputPort(from, portId: 'e1');
    final b = GraphEdgeGeometry.inputPort(to);
    final mid = GraphEdgeGeometry.pointOnCubic(
      a,
      GraphEdgeGeometry.controlOut(a, b),
      GraphEdgeGeometry.controlIn(a, b),
      b,
      0.5,
    );
    expect(
      GraphEdgeGeometry.hitTestEdge(
        nodes: {'a': from, 'b': to},
        edges: const [
          GraphEdgeData(
            id: 'e1',
            fromId: 'a',
            toId: 'b',
            fromPortId: 'e1',
          ),
        ],
        point: mid,
      ),
      'e1',
    );
    expect(
      GraphEdgeGeometry.hitTestEdge(
        nodes: {'a': from, 'b': to},
        edges: const [
          GraphEdgeData(
            id: 'e1',
            fromId: 'a',
            toId: 'b',
            fromPortId: 'e1',
          ),
        ],
        point: const Offset(999, 999),
      ),
      isNull,
    );
  });

  test('cubic path starts and ends at ports', () {
    const a = Offset(0, 0);
    const b = Offset(200, 40);
    final path = GraphEdgeGeometry.cubicPath(a, b);
    final metrics = path.computeMetrics().toList();
    expect(metrics, isNotEmpty);
    final start = metrics.first.getTangentForOffset(0)!.position;
    final end = metrics.first
        .getTangentForOffset(metrics.first.length)!
        .position;
    expect(start.dx, closeTo(0, 0.1));
    expect(start.dy, closeTo(0, 0.1));
    expect(end.dx, closeTo(200, 0.1));
    expect(end.dy, closeTo(40, 0.1));
  });
}
