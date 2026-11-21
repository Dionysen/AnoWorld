import 'dart:io';

import 'package:anoworld/data/project/project_package_archive.dart';
import 'package:anoworld/data/project/project_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('zip and unzip round-trip preserves files', () async {
    final src = await Directory.systemTemp.createTemp('aw_pkg_src_');
    final dest = await Directory.systemTemp.createTemp('aw_pkg_dest_');
    addTearDown(() async {
      if (await src.exists()) await src.delete(recursive: true);
      if (await dest.exists()) await dest.delete(recursive: true);
    });

    await File(p.join(src.path, ProjectPaths.manifestFileName))
        .writeAsString('{"ok":true}\n');
    await File(p.join(src.path, ProjectPaths.projectFileName))
        .writeAsString('{"meta":{}}\n');
    await Directory(p.join(src.path, 'assets')).create();
    await File(p.join(src.path, 'assets', 'a.bin'))
        .writeAsBytes(const <int>[9, 8, 7]);

    final bytes = await ProjectPackageArchive.zipDirectory(src.path);
    expect(bytes.length, greaterThan(32));

    await ProjectPackageArchive.unzipTo(
      bytes: bytes,
      destinationDirectory: dest.path,
    );

    final root = await ProjectPackageArchive.findPackageRoot(dest.path);
    expect(
      await File(p.join(root, ProjectPaths.manifestFileName)).exists(),
      isTrue,
    );
    expect(
      await File(p.join(root, ProjectPaths.projectFileName)).exists(),
      isTrue,
    );
    expect(
      await File(p.join(root, 'assets', 'a.bin')).readAsBytes(),
      <int>[9, 8, 7],
    );
  });
}
