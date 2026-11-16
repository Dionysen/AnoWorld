import 'package:anoworld/domain/models/project.dart';

/// Local project package persistence (folder = editable package).
abstract interface class ProjectRepository {
  Future<List<ProjectSummary>> listProjects();

  Future<Project> create({required String title});

  Future<Project> open(String projectId);

  Future<void> save(Project project);

  Future<void> delete(String projectId);

  /// Copy an external package folder into the library and open it.
  Future<Project> importFromDirectory(String sourceDirectory);

  /// Write a portable copy of [project] into [destinationDirectory].
  Future<void> exportToDirectory({
    required Project project,
    required String destinationDirectory,
  });

  /// Absolute path of the project folder, if it exists.
  Future<String?> directoryFor(String projectId);
}
