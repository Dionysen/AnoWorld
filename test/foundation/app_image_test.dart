import 'dart:convert';
import 'dart:io';
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

  testWidgets('a rewritten file is decoded again', (tester) async {
    final dir = Directory.systemTemp.createTempSync('aw_app_image');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/pic.png')..writeAsBytesSync(_onePixelPng);

    Future<void> pumpFile() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 120,
            height: 80,
            child: AppImage(path: file.path),
          ),
        ),
      );
      await tester.pump();
    }

    ImageProvider shown() => tester.widget<Image>(find.byType(Image)).image;

    await pumpFile();
    final first = shown();
    await pumpFile();
    expect(shown(), first, reason: 'untouched file keeps its cached frame');

    // Same path, new bytes: the cache key has to move with the mtime.
    file.writeAsBytesSync(_onePixelPng);
    file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 1)));
    await pumpFile();
    expect(shown(), isNot(first));
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
