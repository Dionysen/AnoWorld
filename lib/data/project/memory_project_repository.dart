import 'dart:typed_data';

import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';

/// In-memory library for tests and UI harnesses (no disk).
class MemoryProjectRepository implements ProjectRepository {
  MemoryProjectRepository({
    this.factory = const ProjectFactory(),
    String Function()? idGenerator,
    Map<String, Project>? seed,
  })  : _idGenerator = idGenerator ??
            (() {
              _seq += 1;
              return 'p_mem_$_seq';
            }),
        _projects = Map<String, Project>.from(seed ?? const {});

  static int _seq = 0;

  final ProjectFactory factory;
  final String Function() _idGenerator;
  final Map<String, Project> _projects;

  @override
  Future<List<ProjectSummary>> listProjects() async {
    final list = _projects.values
        .map(
          (p) => ProjectSummary(
            id: p.meta.id,
            title: p.meta.title,
            updatedAt: p.meta.updatedAt,
            directoryPath: 'memory://${p.meta.id}',
          ),
        )
        .toList(growable: false);
    return list
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<Project> create({required String title}) async {
    final id = _idGenerator();
    final project = factory.createBlank(id: id, title: title.trim());
    _projects[id] = project;
    return project;
  }

  @override
  Future<Project> open(String projectId) async {
    final project = _projects[projectId];
    if (project == null) {
      throw StateError('Unknown project "$projectId"');
    }
    return project;
  }

  @override
  Future<void> save(Project project) async {
    _projects[project.meta.id] = project.copyWith(
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  @override
  Future<void> delete(String projectId) async {
    _projects.remove(projectId);
  }

  @override
  Future<Project> importFromDirectory(String sourceDirectory) async {
    throw UnsupportedError('MemoryProjectRepository has no directory import');
  }

  @override
  Future<void> exportToDirectory({
    required Project project,
    required String destinationDirectory,
  }) async {
    throw UnsupportedError('MemoryProjectRepository has no directory export');
  }

  @override
  Future<Uint8List> exportPackageBytes({required Project project}) async {
    throw UnsupportedError('MemoryProjectRepository has no package export');
  }

  @override
  Future<Project> importFromPackageBytes(Uint8List bytes) async {
    throw UnsupportedError('MemoryProjectRepository has no package import');
  }

  @override
  Future<String?> directoryFor(String projectId) async {
    if (_projects.containsKey(projectId)) return 'memory://$projectId';
    return null;
  }
}
