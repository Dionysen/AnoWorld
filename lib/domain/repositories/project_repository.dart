import 'dart:typed_data';

import 'package:anoworld/domain/models/project.dart';

/// Local project package persistence (folder = editable package).
abstract interface class ProjectRepository {
  Future<List<ProjectSummary>> listProjects();

  Future<Project> create({required String title});

  Future<Project> open(String projectId);

  Future<void> save(Project project);

  Future<void> delete(String projectId);

  /// Copy an external package folder into the library and open it.
  ///
  /// If [projectId] already exists, assigns a new id so import always succeeds.
  Future<Project> importFromDirectory(String sourceDirectory);

  /// Write a portable copy of [project] into [destinationDirectory].
  Future<void> exportToDirectory({
    required Project project,
    required String destinationDirectory,
  });

  /// Zip the full package (`manifest` + `project.json` + `assets/`).
  Future<Uint8List> exportPackageBytes({required Project project});

  /// Import a `.anoworld` / `.zip` package; remints id on conflict.
  Future<Project> importFromPackageBytes(Uint8List bytes);

  /// Absolute path of the project folder, if it exists.
  Future<String?> directoryFor(String projectId);
}
