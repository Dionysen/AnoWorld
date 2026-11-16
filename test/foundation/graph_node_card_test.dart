import 'package:anoworld/foundation/graph/graph_node_card.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows badge bar and title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: Center(
            child: GraphNodeCard(
              title: '城门',
              subtitle: '离开',
              badgeLabel: '开场',
              badgeColor: Colors.teal,
              elevated: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('开场'), findsOneWidget);
    expect(find.text('城门'), findsOneWidget);
    expect(find.text('离开'), findsOneWidget);

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(GraphNodeCard),
        matching: find.byType(Material),
      ),
    );
    expect(material.elevation, AppTheme.surfaceElevation);
  });
}
