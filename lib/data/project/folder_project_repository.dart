import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:anoworld/data/project/project_cover_files.dart';
import 'package:anoworld/data/project/project_package_archive.dart';
import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:path/path.dart' as p;

class ProjectIoException implements Exception {
  ProjectIoException(this.message);

  final String message;

  @override
  String toString() => 'ProjectIoException: $message';
}

/// Folder package layout:
/// ```text
/// {library}/projects/{id}/
///   manifest.json
///   project.json
///   assets/
/// ```
class FolderProjectRepository implements ProjectRepository {
  FolderProjectRepository({
    ProjectPaths? paths,
    this.factory = const ProjectFactory(),
    String Function()? idGenerator,
  })  : _paths = paths ?? ProjectPaths(),
        _idGenerator = idGenerator ?? _defaultId;

  final ProjectPaths _paths;
  final ProjectFactory factory;
  final String Function() _idGenerator;

  static final _random = Random();

  static String _defaultId() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 20).toRadixString(16).padLeft(5, '0');
    return 'p_$millis$suffix';
  }

  @override
  Future<List<ProjectSummary>> listProjects() async {
    final root = Directory(await _paths.projectsRoot());
    if (!await root.exists()) return const <ProjectSummary>[];

    final summaries = <ProjectSummary>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      try {
        final manifest = await _readManifest(entity.path);
        summaries.add(
          ProjectSummary(
            id: manifest.projectId,
            title: manifest.title,
            updatedAt: manifest.updatedAt,
            directoryPath: entity.path,
            coverPath: await ProjectCoverFiles.findExistingRelative(
              entity.path,
            ),
          ),
        );
      } on Object {
        // Skip corrupt / foreign folders.
      }
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  @override
  Future<Project> create({required String title}) async {
    final id = _idGenerator();
    final project = factory.createBlank(id: id, title: title.trim());
    await _writeProjectDirectory(
      directory: await _paths.projectDirectory(id),
      project: project,
      overwrite: false,
    );
    return project;
  }

  @override
  Future<Project> open(String projectId) async {
    final dir = await _paths.projectDirectory(projectId);
    return _readProjectDirectory(dir);
  }

  @override
  Future<void> save(Project project) async {
    final stamped = project.copyWith(
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    await _writeProjectDirectory(
      directory: await _paths.projectDirectory(stamped.meta.id),
      project: stamped,
      overwrite: true,
    );
  }

  @override
  Future<void> delete(String projectId) async {
    final dir = Directory(await _paths.projectDirectory(projectId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<Project> importFromDirectory(String sourceDirectory) async {
    final source = Directory(sourceDirectory);
    if (!await source.exists()) {
      throw ProjectIoException('找不到要导入的故事包');
    }
    var project = await _readProjectDirectory(source.path);
    var targetId = project.meta.id;
    var targetDir = await _paths.projectDirectory(targetId);
    final reminted = await Directory(targetDir).exists();
    if (reminted) {
      targetId = _idGenerator();
      project = project.copyWith(
        meta: project.meta.copyWith(
          id: targetId,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      targetDir = await _paths.projectDirectory(targetId);
    }
    await _copyDirectory(source.path, targetDir);
    if (reminted) {
      await _writeProjectDirectory(
        directory: targetDir,
        project: project,
        overwrite: true,
      );
    }
    return _readProjectDirectory(targetDir);
  }

  @override
  Future<void> exportToDirectory({
    required Project project,
    required String destinationDirectory,
  }) async {
    final sourceDir = await _paths.projectDirectory(project.meta.id);
    if (!await Directory(sourceDir).exists()) {
      // Persist first so assets/ exist even for in-memory-only projects.
      await _writeProjectDirectory(
        directory: sourceDir,
        project: project,
        overwrite: true,
      );
    } else {
      await save(project);
    }
    final dest = Directory(destinationDirectory);
    if (await dest.exists()) {
      await dest.delete(recursive: true);
    }
    await _copyDirectory(sourceDir, destinationDirectory);
  }

  @override
  Future<Uint8List> exportPackageBytes({required Project project}) async {
    final sourceDir = await _paths.projectDirectory(project.meta.id);
    if (!await Directory(sourceDir).exists()) {
      await _writeProjectDirectory(
        directory: sourceDir,
        project: project,
        overwrite: true,
      );
    } else {
      await save(project);
    }
    return ProjectPackageArchive.zipDirectory(sourceDir);
  }

  @override
  Future<Project> importFromPackageBytes(Uint8List bytes) async {
    final temp = await Directory.systemTemp.createTemp('anoworld_import_');
    try {
      await ProjectPackageArchive.unzipTo(
        bytes: bytes,
        destinationDirectory: temp.path,
      );
      final root = await ProjectPackageArchive.findPackageRoot(temp.path);
      return await importFromDirectory(root);
    } finally {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  }

  @override
  Future<String?> directoryFor(String projectId) async {
    final dir = await _paths.projectDirectory(projectId);
    if (await Directory(dir).exists()) return dir;
    return null;
  }

  Future<Project> _readProjectDirectory(String directory) async {
    await _readManifest(directory);
    final projectFile = File(_paths.projectJsonPath(directory));
    if (!await projectFile.exists()) {
      throw ProjectIoException('Missing ${ProjectPaths.projectFileName}');
    }
    final decoded = jsonDecode(await projectFile.readAsString());
    final map = asJsonMap(decoded, path: ProjectPaths.projectFileName);
    return Project.fromJson(map);
  }

  Future<ProjectManifest> _readManifest(String directory) async {
    final file = File(_paths.manifestPath(directory));
    if (!await file.exists()) {
      throw ProjectIoException('Missing ${ProjectPaths.manifestFileName}');
    }
    final decoded = jsonDecode(await file.readAsString());
    return ProjectManifest.fromJson(
      asJsonMap(decoded, path: ProjectPaths.manifestFileName),
    );
  }

  Future<void> _writeProjectDirectory({
    required String directory,
    required Project project,
    required bool overwrite,
  }) async {
    final dir = Directory(directory);
    if (await dir.exists()) {
      if (!overwrite) {
        throw ProjectIoException('Project directory already exists: $directory');
      }
    } else {
      await dir.create(recursive: true);
    }
    await Directory(_paths.assetsDirectory(directory)).create(recursive: true);

    final encoder = const JsonEncoder.withIndent('  ');
    final manifest = ProjectManifest.fromProject(project);
    await File(_paths.manifestPath(directory))
        .writeAsString('${encoder.convert(manifest.toJson())}\n');
    await File(_paths.projectJsonPath(directory))
        .writeAsString('${encoder.convert(project.toJson())}\n');
  }

  Future<void> _copyDirectory(String from, String to) async {
    final source = Directory(from);
    await Directory(to).create(recursive: true);
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: from);
      final targetPath = p.join(to, relative);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }
}
