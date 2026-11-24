import 'dart:convert';
import 'dart:io';

import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/widgets/app_image.dart';
import 'package:anoworld/foundation/widgets/app_shaped_avatar.dart';
import 'package:anoworld/home/library_browse_views.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('list view paints the story cover inside the avatar', (
    tester,
  ) async {
    final cover = (await tester.runAsync(_writeCover))!;
    await tester.pumpWidget(
      testLocalized(
        home: _browse(
          mode: LibraryViewMode.list,
          covers: {'p1': cover.path},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppShapedAvatar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppShapedAvatar),
        matching: find.byType(AppImage),
      ),
      findsOneWidget,
    );
  });

  testWidgets('grid view paints the story cover on the tile', (tester) async {
    final cover = (await tester.runAsync(_writeCover))!;
    await tester.pumpWidget(
      testLocalized(
        home: _browse(
          mode: LibraryViewMode.grid,
          covers: {'p1': cover.path},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppImage), findsOneWidget);
  });

  testWidgets('stories without a cover keep the letter placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      testLocalized(home: _browse(mode: LibraryViewMode.grid)),
    );
    await tester.pump();

    expect(find.byType(AppImage), findsNothing);
    expect(find.text('雨'), findsOneWidget);
  });

  testWidgets('list multi-select swaps more for a trailing checkbox', (
    tester,
  ) async {
    final selection = LibrarySelectionController()..enter(null);
    await tester.pumpWidget(
      testLocalized(
        home: _browse(mode: LibraryViewMode.list, selection: selection),
      ),
    );
    await tester.pump();

    expect(find.byType(AppShapedAvatar), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

    await tester.tap(find.text('雨夜'));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byType(AppShapedAvatar), findsOneWidget);
  });

  testWidgets('simple list multi-select swaps trailing for a checkbox', (
    tester,
  ) async {
    final selection = LibrarySelectionController()..enter(null);
    await tester.pumpWidget(
      testLocalized(
        home: _browse(mode: LibraryViewMode.simpleList, selection: selection),
      ),
    );
    await tester.pump();

    expect(find.byType(AppShapedAvatar), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
  });
}

Future<File> _writeCover() async {
  final dir = await Directory.systemTemp.createTemp('aw_library_cover_');
  addTearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  final file = File('${dir.path}/cover.png');
  await file.writeAsBytes(_onePixelPng);
  return file;
}

Widget _browse({
  required LibraryViewMode mode,
  Map<String, String> covers = const {},
  LibrarySelectionController? selection,
}) {
  final controller = selection ?? LibrarySelectionController();
  return Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => LibraryBrowseViews(
        viewMode: mode,
        avatarShape: LibraryAvatarShape.circle,
        folders: const [],
        projects: [
          ProjectSummary(
            id: 'p1',
            title: '雨夜',
            updatedAt: DateTime.utc(2026, 1, 1),
            directoryPath: '/tmp/p1',
          ),
        ],
        covers: covers,
        selection: controller,
        onOpenFolder: (_) {},
        onOpenProject: (_) {},
        onFolderMenu: (_) {},
        onProjectMenu: (_) {},
        formatUpdated: (_) => '',
      ),
    ),
  );
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
