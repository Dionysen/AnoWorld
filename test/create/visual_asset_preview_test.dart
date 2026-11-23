import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/create/visual_asset_preview.dart';
import 'package:anoworld/foundation/widgets/app_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/test_app.dart';

void main() {
  late Directory dir;
  late File imageFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('aw_visual_preview');
    imageFile = File(p.join(dir.path, 'picture.png'))
      ..writeAsBytesSync(_transparentPng());
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('shows the empty label without a picture', (tester) async {
    await tester.pumpWidget(
      testLocalized(
        home: const Scaffold(
          body: VisualAssetPreview(file: null, emptyLabel: '还没有场景图'),
        ),
      ),
    );
    expect(find.text('还没有场景图'), findsOneWidget);
  });

  testWidgets('tapping the picture opens the zoomable viewer', (tester) async {
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: VisualAssetPreview(file: imageFile, emptyLabel: '还没有场景图'),
        ),
      ),
    );

    await tester.tap(find.byType(Image));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AppImageViewer), findsOneWidget);
  });

  testWidgets('the action button never opens the viewer', (tester) async {
    var regenerated = 0;
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: VisualAssetPreview(
            file: imageFile,
            emptyLabel: '还没有场景图',
            actionLabel: '重新画场景',
            onAction: () => regenerated++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('重新画场景'));
    await tester.pump();
    expect(regenerated, 1);
    expect(find.byType(AppImageViewer), findsNothing);
  });

  testWidgets('zoomable false keeps the picture inert', (tester) async {
    await tester.pumpWidget(
      testLocalized(
        home: Scaffold(
          body: VisualAssetPreview(
            file: imageFile,
            emptyLabel: '还没有场景图',
            zoomable: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Image));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AppImageViewer), findsNothing);
  });
}

/// Minimal 1×1 transparent PNG so the preview has a decodable picture.
Uint8List _transparentPng() {
  return Uint8List.fromList(const <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);
}
