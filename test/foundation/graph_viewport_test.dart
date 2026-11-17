import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_chip.dart';
import 'package:anoworld/foundation/graph/graph_viewport.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders nodes in tight constraints without overflow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 200,
            child: GraphViewport(
              nodes: const [
                GraphNodeData(id: 'a', label: 'A', x: 20, y: 20),
                GraphNodeData(id: 'b', label: 'B', x: 200, y: 40),
              ],
              edges: const [
                GraphEdgeData(id: 'e', fromId: 'a', toId: 'b'),
              ],
              selectedId: null,
              onSelect: (_) {},
              onMove: (_, __, ___) {},
              onConnect: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects node on tap', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: GraphViewport(
              nodes: const [
                GraphNodeData(id: 'a', label: 'Alpha', x: 40, y: 40),
              ],
              edges: const [],
              selectedId: selected,
              onSelect: (id) => selected = id,
              onMove: (_, __, ___) {},
              onConnect: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(selected, 'a');
  });

  testWidgets('tapping subtitle selects node', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 320,
            child: GraphViewport(
              nodes: const [
                GraphNodeData(
                  id: 'a',
                  label: '戏台檐下',
                  subtitle: '阿汛用一句实话换到今晚出城的门路',
                  x: 40,
                  y: 40,
                  inputLabel: '进入',
                ),
              ],
              edges: const [],
              selectedId: selected,
              onSelect: (id) => selected = id,
              onMove: (_, __, ___) {},
              onConnect: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('阿汛用一句实话换到今晚出城的门路'));
    await tester.pump();
    expect(selected, 'a');
  });

  testWidgets('tapping a wire selects the edge', (tester) async {
    String? selectedEdge;
    String? selectedNode = 'keep';
    const from = GraphNodeData(
      id: 'a',
      label: 'Alpha',
      x: 40,
      y: 40,
      width: 120,
      height: 80,
      outputs: [GraphOutputPort(id: 'e1')],
    );
    const to = GraphNodeData(
      id: 'b',
      label: 'Beta',
      x: 280,
      y: 40,
      width: 120,
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 360,
            child: GraphViewport(
              nodes: const [from, to],
              edges: const [
                GraphEdgeData(
                  id: 'e1',
                  fromId: 'a',
                  toId: 'b',
                  fromPortId: 'e1',
                ),
              ],
              selectedId: selectedNode,
              selectedEdgeId: selectedEdge,
              onSelect: (id) => selectedNode = id,
              onSelectEdge: (id) => selectedEdge = id,
              onMove: (_, __, ___) {},
              onConnect: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Child space is layout + [GraphViewport.sceneTopInset] on Y.
    await tester.tapAt(
      Offset(mid.dx, mid.dy + GraphViewport.sceneTopInset),
    );
    await tester.pump();
    expect(selectedEdge, 'e1');
    expect(selectedNode, isNull);
  });

  testWidgets('dragging output port onto input connects nodes', (tester) async {
    String? from;
    String? to;
    String? port;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 320,
            child: GraphViewport(
              nodes: const [
                GraphNodeData(id: 'a', label: 'Alpha', x: 40, y: 40),
                GraphNodeData(id: 'b', label: 'Beta', x: 260, y: 40),
              ],
              edges: const [],
              selectedId: null,
              onSelect: (_) {},
              onMove: (_, __, ___) {},
              onConnect: (f, t, p) {
                from = f;
                to = t;
                port = p;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.timedDrag(
      find.byKey(
        const ValueKey('graph_port_out_a___pending__'),
      ),
      const Offset(55, 0),
      const Duration(milliseconds: 280),
    );
    await tester.pumpAndSettle();
    expect(from, 'a');
    expect(to, 'b');
    expect(port, GraphOutputPort.pendingId);
  });

  testWidgets('multiple output ports render and drag by edge id', (tester) async {
    String? from;
    String? to;
    String? port;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 400,
            child: GraphViewport(
              nodes: const [
                GraphNodeData(
                  id: 'a',
                  label: 'Alpha',
                  x: 40,
                  y: 40,
                  outputs: [
                    GraphOutputPort(id: 'e1', label: 'True'),
                    GraphOutputPort(id: 'e2', label: 'False'),
                    GraphOutputPort.pendingPort,
                  ],
                ),
                GraphNodeData(id: 'b', label: 'Beta', x: 300, y: 80),
                GraphNodeData(id: 'c', label: 'Gamma', x: 300, y: 220),
              ],
              edges: const [
                GraphEdgeData(
                  id: 'e1',
                  fromId: 'a',
                  toId: 'b',
                  fromPortId: 'e1',
                ),
                GraphEdgeData(
                  id: 'e2',
                  fromId: 'a',
                  toId: 'c',
                  fromPortId: 'e2',
                ),
              ],
              selectedId: null,
              onSelect: (_) {},
              onMove: (_, __, ___) {},
              onConnect: (f, t, p) {
                from = f;
                to = t;
                port = p;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('graph_port_out_a_e1')), findsOneWidget);
    expect(find.byKey(const ValueKey('graph_port_out_a_e2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('graph_port_out_a___pending__')),
      findsOneWidget,
    );
    expect(find.text('True'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);

    await tester.timedDrag(
      find.byKey(const ValueKey('graph_port_out_a_e2')),
      const Offset(90, -10),
      const Duration(milliseconds: 280),
    );
    await tester.pumpAndSettle();
    expect(from, 'a');
    expect(to, 'b');
    expect(port, 'e2');
  });

  testWidgets('focusSelected locks camera onto selected node', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: GraphViewport(
              nodes: const [
                GraphNodeData(
                  id: 'a',
                  label: 'Alpha',
                  x: 40,
                  y: 40,
                  width: 120,
                  height: 80,
                ),
              ],
              edges: const [],
              selectedId: 'a',
              focusSelected: true,
              onSelect: (_) {},
              onMove: (_, __, ___) {},
              onConnect: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.panEnabled, isFalse);
    expect(viewer.scaleEnabled, isFalse);
    final scale = viewer.transformationController!.value.getMaxScaleOnAxis();
    expect(scale, greaterThan(1.0));
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('chip pointer down arms drag', (tester) async {
    var armed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: Center(
            child: GraphNodeChip(
              data: const GraphNodeData(id: 'a', label: 'Alpha', x: 0, y: 0),
              selected: true,
              onTap: () {},
              onPanDown: (_) => armed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GraphNodeChip)));
    await tester.pump();
    await gesture.up();
    expect(armed, isTrue);
  });

  testWidgets(
      'node drag keeps up when multiple moves land before rebuild',
      (tester) async {
    // Reproduces Windows high-rate mice: several PointerMoves in one frame
    // while parent still holds the pre-drag layout. Absolute canvas tracking
    // must keep the full pointer travel; stale node.x+delta would drop all
    // but the last segment.
    late StateSetter setHarness;
    var node = const GraphNodeData(
      id: 'a',
      label: 'Alpha',
      x: 80,
      y: 60,
      width: 160,
      height: 96,
    );
    final xs = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHarness = setState;
              return SizedBox(
                width: 640,
                height: 480,
                child: GraphViewport(
                  nodes: [node],
                  edges: const [],
                  selectedId: 'a',
                  onSelect: (_) {},
                  onMove: (id, x, y) {
                    xs.add(x);
                    setHarness(() {
                      node = GraphNodeData(
                        id: node.id,
                        label: node.label,
                        x: x,
                        y: y,
                        width: node.width,
                        height: node.height,
                      );
                    });
                  },
                  onConnect: (_, __, ___) {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final start = tester.getCenter(find.byType(GraphNodeChip));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(xs, isNotEmpty);
    final xAfterFirst = xs.last;
    xs.clear();
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(xs, isNotEmpty);
    expect(xs.last, closeTo(xAfterFirst + 60, 1.0));
  });
}
