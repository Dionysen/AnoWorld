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
}
