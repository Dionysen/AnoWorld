import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/data/project/project_cover_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('importFromBytes writes cover.png', () async {
    final dir = await Directory.systemTemp.createTemp('aw_cover_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final relative = await ProjectCoverFiles.importFromBytes(
      projectDir: dir.path,
      bytes: Uint8List.fromList(const [9, 8, 7]),
      extension: 'png',
    );
    expect(relative, 'cover.png');
    final file = File(
      p.join(dir.path, 'assets', 'cover.png'),
    );
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), <int>[9, 8, 7]);
  });

  test('findExistingRelative finds cover.* and ignores other assets', () async {
    final dir = await Directory.systemTemp.createTemp('aw_cover_scan_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final assets = Directory(p.join(dir.path, 'assets'));
    await assets.create(recursive: true);
    await File(p.join(assets.path, 'scene.png')).writeAsBytes(const [1]);
    await File(p.join(assets.path, 'cover.WEBP')).writeAsBytes(const [2]);

    expect(
      await ProjectCoverFiles.findExistingRelative(dir.path),
      'cover.WEBP',
    );
    expect(
      await ProjectCoverFiles.resolveExistingRelative(dir.path, null),
      'cover.WEBP',
    );
    expect(
      await ProjectCoverFiles.resolveExistingRelative(dir.path, 'cover.png'),
      'cover.WEBP',
    );
    expect(
      await ProjectCoverFiles.resolveExistingRelative(dir.path, 'cover.WEBP'),
      'cover.WEBP',
    );
  });

  test('resolveExistingRelative returns null without a cover', () async {
    final dir = await Directory.systemTemp.createTemp('aw_no_cover_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    expect(
      await ProjectCoverFiles.resolveExistingRelative(dir.path, null),
      isNull,
    );
    expect(
      await ProjectCoverFiles.resolveExistingRelative(dir.path, 'cover.png'),
      isNull,
    );
  });
}
