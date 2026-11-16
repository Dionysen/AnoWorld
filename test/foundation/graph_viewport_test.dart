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
              onConnect: (_, __) {},
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
              onConnect: (_, __) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(selected, 'a');
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
