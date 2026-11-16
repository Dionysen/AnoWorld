import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('elevated surface uses theme elevation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: Center(
            child: AppSurface(
              elevated: true,
              child: Text('站卡片'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppSurface),
        matching: find.byType(Material),
      ),
    );
    expect(material.elevation, AppTheme.surfaceElevation);
    expect(find.text('站卡片'), findsOneWidget);
  });

  testWidgets('flat surface stays at zero elevation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: AppSurface(child: Text('平面')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppSurface),
        matching: find.byType(Material),
      ),
    );
    expect(material.elevation, 0);
  });
}
