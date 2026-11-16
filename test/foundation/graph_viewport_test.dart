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

  testWidgets('chip pan notifies onMove callback', (tester) async {
    var panned = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: Center(
            child: GraphNodeChip(
              data: const GraphNodeData(id: 'a', label: 'Alpha', x: 0, y: 0),
              selected: true,
              onTap: () {},
              onPanUpdate: (_) => panned = true,
              onPanEnd: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.text('Alpha'), const Offset(24, 12));
    await tester.pump();
    expect(panned, isTrue);
  });
}
