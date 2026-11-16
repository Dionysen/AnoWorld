import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the AnoWorld library root and project folders.
///
/// Persisted asset paths inside a project stay relative to that project's
/// `assets/` directory (NativeTavern-style relative storage).
class ProjectPaths {
  ProjectPaths({
    this.libraryFolderName = 'AnoWorld',
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  static const String projectsFolder = 'projects';
  static const String manifestFileName = 'manifest.json';
  static const String projectFileName = 'project.json';
  static const String assetsFolder = 'assets';

  final String libraryFolderName;
  final Future<Directory> Function() _documentsDirectory;

  String? _cachedLibraryRoot;

  /// Injected absolute library root (tests).
  void seedLibraryRoot(String absolutePath) {
    _cachedLibraryRoot = absolutePath;
  }

  Future<String> libraryRoot() async {
    final cached = _cachedLibraryRoot;
    if (cached != null) return cached;
    final docs = await _documentsDirectory();
    final root = p.join(docs.path, libraryFolderName);
    await Directory(root).create(recursive: true);
    return _cachedLibraryRoot = root;
  }

  Future<String> projectsRoot() async {
    final root = p.join(await libraryRoot(), projectsFolder);
    await Directory(root).create(recursive: true);
    return root;
  }

  Future<String> projectDirectory(String projectId) async {
    return p.join(await projectsRoot(), projectId);
  }

  String manifestPath(String projectDir) =>
      p.join(projectDir, manifestFileName);

  String projectJsonPath(String projectDir) =>
      p.join(projectDir, projectFileName);

  String assetsDirectory(String projectDir) =>
      p.join(projectDir, assetsFolder);

  /// Normalize relative asset paths to POSIX separators for the catalog.
  static String normalizeRelativeAssetPath(String relativePath) {
    return relativePath.replaceAll('\\', '/');
  }
}
