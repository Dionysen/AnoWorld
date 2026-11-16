import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_overview_map.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overview map renders nodes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: GraphOverviewMap(
            nodes: const [
              GraphNodeData(id: 'a', label: '甲', x: 20, y: 20),
              GraphNodeData(id: 'b', label: '乙', x: 200, y: 80),
            ],
            edges: const [
              GraphEdgeData(id: 'e', fromId: 'a', toId: 'b'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}