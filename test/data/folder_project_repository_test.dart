import 'dart:io';

import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/project/project_package_archive.dart';
import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late ProjectPaths paths;
  late FolderProjectRepository repo;
  var nextId = 0;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('anoworld_projects_');
    paths = ProjectPaths(
      documentsDirectory: () async => tempRoot,
    );
    paths.seedLibraryRoot(p.join(tempRoot.path, 'AnoWorld'));
    nextId = 0;
    repo = FolderProjectRepository(
      paths: paths,
      idGenerator: () {
        nextId += 1;
        return nextId == 1 ? 'p_fixed' : 'p_remint_$nextId';
      },
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

  test('export and import zip package with assets', () async {
    final sample = const ProjectFactory().createRainNightSample(
      id: 'proj_rain_night',
      now: DateTime.utc(2026, 1, 1),
    );
    await repo.save(sample);
    final projectDir = await paths.projectDirectory(sample.meta.id);
    final assetFile = File(p.join(projectDir, 'assets', 'cover.png'));
    await assetFile.parent.create(recursive: true);
    await assetFile.writeAsBytes(const <int>[1, 2, 3, 4]);

    final listed = await repo.listProjects();
    expect(listed.single.coverPath, 'cover.png');

    final bytes = await repo.exportPackageBytes(project: sample);
    expect(bytes, isNotEmpty);

    final probe = await Directory.systemTemp.createTemp('aw_zip_probe_');
    addTearDown(() async {
      if (await probe.exists()) await probe.delete(recursive: true);
    });
    await ProjectPackageArchive.unzipTo(
      bytes: bytes,
      destinationDirectory: probe.path,
    );
    final names = <String>[];
    await for (final entity in probe.list(recursive: true)) {
      if (entity is File) {
        names.add(p.relative(entity.path, from: probe.path));
      }
    }
    expect(
      names.map((n) => n.replaceAll('\\', '/')),
      containsAll(<String>[
        ProjectPaths.manifestFileName,
        ProjectPaths.projectFileName,
        'assets/cover.png',
      ]),
    );

    await repo.delete('proj_rain_night');
    expect(await repo.listProjects(), isEmpty);

    final imported = await repo.importFromPackageBytes(bytes);
    expect(imported.meta.id, 'proj_rain_night');
    expect(imported.main.beats, hasLength(2));

    final importedDir = await paths.projectDirectory(imported.meta.id);
    expect(
      File(p.join(importedDir, 'assets', 'cover.png')).existsSync(),
      isTrue,
    );
    expect(
      await File(p.join(importedDir, 'assets', 'cover.png')).readAsBytes(),
      <int>[1, 2, 3, 4],
    );
  });

  test('import remints id when project already exists', () async {
    final sample = const ProjectFactory().createRainNightSample(
      id: 'proj_rain_night',
      now: DateTime.utc(2026, 1, 1),
    );
    await repo.save(sample);

    final bytes = await repo.exportPackageBytes(project: sample);
    final reminted = await repo.importFromPackageBytes(bytes);
    expect(reminted.meta.id, isNot('proj_rain_night'));
    expect(reminted.meta.title, sample.meta.title);
    expect(await repo.listProjects(), hasLength(2));
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
