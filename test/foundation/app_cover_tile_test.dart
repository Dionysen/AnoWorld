import 'package:anoworld/foundation/widgets/app_cover_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('add-only cover tile draws an outline for edge contrast', (
    tester,
  ) async {
    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: SizedBox(
                width: 120,
                height: 160,
                child: AppCoverTile(
                  cover: const Center(child: Icon(Icons.add)),
                  onTap: () {},
                  semanticLabel: '添加',
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppCoverTile),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape!;
    expect(shape, isA<OutlinedBorder>());
    expect(
      (shape as OutlinedBorder).side.color,
      scheme.outline,
    );
  });

  testWidgets('story cover tiles stay borderless', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: AppCoverTile(
              title: '雨夜',
              cover: const ColoredBox(color: Colors.teal),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppCoverTile),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape! as OutlinedBorder;
    expect(shape.side, BorderSide.none);
  });
}
