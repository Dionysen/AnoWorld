import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_overview_map.dart';
import 'package:anoworld/foundation/graph/graph_viewport_controller.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overview map shows thumbnails area and fixed viewport frame',
      (tester) async {
    final camera = GraphViewportController();
    addTearDown(camera.dispose);
    camera.viewportSize = const Size(400, 300);
    camera.setVisibleSceneTopLeft(const Offset(0, 0));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 320,
            child: GraphOverviewMap(
              camera: camera,
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
      ),
    );
    await tester.pump();

    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('graph-overview-viewport-frame')),
      findsOneWidget,
    );

    final before = camera.visibleSceneRect!;
    await tester.drag(
      find.byType(GraphOverviewMap),
      const Offset(40, 0),
    );
    await tester.pump();
    final after = camera.visibleSceneRect!;
    expect(after.left, lessThan(before.left));
    expect(after.width / after.height, closeTo(400 / 300, 0.01));
    expect(tester.takeException(), isNull);
  });
}
