import 'dart:io';

import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late FolderProjectRepository repo;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('anoworld_projects_');
    final paths = ProjectPaths(
      documentsDirectory: () async => tempRoot,
    );
    paths.seedLibraryRoot(p.join(tempRoot.path, 'AnoWorld'));
    repo = FolderProjectRepository(
      paths: paths,
      idGenerator: () => 'p_fixed',
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('create, open, save round-trip', () async {
    final created = await repo.create(title: '测试作品');
    expect(created.meta.id, 'p_fixed');
    expect(created.meta.title, '测试作品');

    final opened = await repo.open('p_fixed');
    expect(opened.meta.title, '测试作品');
    expect(opened.main.startNodeId, isNotEmpty);

    final renamed = opened.copyWith(
      meta: opened.meta.copyWith(title: '改名'),
    );
    await repo.save(renamed);

    final again = await repo.open('p_fixed');
    expect(again.meta.title, '改名');

    final listed = await repo.listProjects();
    expect(listed, hasLength(1));
    expect(listed.single.title, '改名');
  });

  test('export and import directory package', () async {
    final sample = const ProjectFactory().createRainNightSample(
      id: 'proj_rain_night',
      now: DateTime.utc(2026, 1, 1),
    );
    await repo.save(sample);

    final exportDir = p.join(tempRoot.path, 'export_pack');
    await repo.exportToDirectory(
      project: sample,
      destinationDirectory: exportDir,
    );

    expect(
      File(p.join(exportDir, ProjectPaths.manifestFileName)).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(exportDir, ProjectPaths.projectFileName)).existsSync(),
      isTrue,
    );

    await repo.delete('proj_rain_night');
    expect(await repo.listProjects(), isEmpty);

    final imported = await repo.importFromDirectory(exportDir);
    expect(imported.meta.id, 'proj_rain_night');
    expect(imported.main.beats, hasLength(2));
    expect(await repo.listProjects(), hasLength(1));
  });

  test('rejects foreign manifest format', () async {
    final badDir = Directory(p.join(tempRoot.path, 'bad_pack'));
    await badDir.create(recursive: true);
    await File(p.join(badDir.path, ProjectPaths.manifestFileName)).writeAsString(
      '{"format":"other","schemaVersion":1,"projectId":"x","title":"t","updatedAt":"2026-01-01T00:00:00.000Z"}',
    );
    await File(p.join(badDir.path, ProjectPaths.projectFileName)).writeAsString('{}');

    expect(
      () => repo.importFromDirectory(badDir.path),
      throwsA(isA<FormatException>()),
    );
  });
}
