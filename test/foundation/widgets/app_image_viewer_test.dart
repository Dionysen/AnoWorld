import 'dart:io';

import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_app.dart';

void main() {
  late Directory dir;
  late File imageFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('aw_image_viewer');
    imageFile = File(p.join(dir.path, 'picture.png'))
      ..writeAsBytesSync(_transparentPng());
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> openViewer(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      testLocalized(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    showAppImageViewer(context, path: imageFile.path),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('tapping a picture opens the viewer and a tap dismisses it', (
    tester,
  ) async {
    await openViewer(tester);
    expect(find.byType(AppImageViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('双击缩放，点一下关闭'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(InteractiveViewer)));
    await tester.pump();
    // A single tap waits out the double-tap timeout before dismissing.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(AppImageViewer), findsNothing);
  });

  testWidgets('double tap zooms in and out', (tester) async {
    await openViewer(tester);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final transform = viewer.transformationController!;
    final center = tester.getCenter(find.byType(InteractiveViewer));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(transform.value.getMaxScaleOnAxis(), greaterThan(1.5));
    expect(find.byType(AppImageViewer), findsOneWidget);

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(transform.value.getMaxScaleOnAxis(), closeTo(1, 0.01));
  });

  testWidgets('Escape closes the viewer', (tester) async {
    await openViewer(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AppImageViewer), findsNothing);
  });

  testWidgets('close button dismisses the viewer', (tester) async {
    await openViewer(tester);
    await tester.tap(find.byTooltip('关闭预览'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AppImageViewer), findsNothing);
  });

  testWidgets('close button stays below the window title band', (tester) async {
    const band = 72.0;
    final theme = AppTheme.data.copyWith(
      appBarTheme: AppTheme.data.appBarTheme.copyWith(toolbarHeight: band),
    );
    await openViewer(tester, theme: theme);
    final rect = tester.getRect(find.byType(AppCircleButton));
    expect(rect.top, greaterThanOrEqualTo(band));
  });
}

/// Minimal 1×1 transparent PNG so the viewer has a decodable provider.
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
