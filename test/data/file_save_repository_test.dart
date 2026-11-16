import 'dart:io';

import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/data/save/file_save_repository.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('file save repository round-trips a slot', () async {
    final temp = await Directory.systemTemp.createTemp('anoworld_saves_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final paths = ProjectPaths(documentsDirectory: () async => temp);
    paths.seedLibraryRoot(p.join(temp.path, 'AnoWorld'));
    final repo = FileSaveRepository(paths: paths);

    await repo.save(
      projectId: 'proj_rain_night',
      pointer: const MainSavePointer(nodeId: 'n2', beatId: 'b2'),
    );
    final loaded = await repo.load('proj_rain_night');
    expect(loaded, isNotNull);
    expect(loaded!.pointer.nodeId, 'n2');
    expect(loaded.pointer.beatId, 'b2');

    await repo.clear('proj_rain_night');
    expect(await repo.load('proj_rain_night'), isNull);
  });
}
