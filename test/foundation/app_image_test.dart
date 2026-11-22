import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/foundation/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders bytes and falls back when empty', (tester) async {
    const fallbackKey = ValueKey<String>('fallback');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 80,
          child: AppImage(
            bytes: Uint8List.fromList(_onePixelPng),
            fallback: const SizedBox(key: fallbackKey),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(fallbackKey), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: AppImage(fallback: const SizedBox(key: fallbackKey)),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byKey(fallbackKey), findsOneWidget);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
