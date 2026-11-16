import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_visual.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('visual shows header and port titles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: GraphNodeVisual(
            data: const GraphNodeData(
              id: 'a',
              label: '戏台檐下',
              subtitle: '换到出城的门路',
              badgeLabel: '过程',
              x: 0,
              y: 0,
              inputLabel: '进入',
              outputs: [
                GraphOutputPort(id: 'e1', label: '继续'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('戏台檐下'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(find.text('进入'), findsOneWidget);
  });
}