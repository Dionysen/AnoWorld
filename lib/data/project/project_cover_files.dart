import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/data/project/project_paths.dart';
import 'package:path/path.dart' as p;

/// Story cover image under `assets/cover.{ext}`.
abstract final class ProjectCoverFiles {
  static const String fileStem = 'cover';

  static const Set<String> allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  };

  static String relativePath(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    return ProjectPaths.normalizeRelativeAssetPath('$fileStem.$ext');
  }

  static String absolutePath(String projectDir, String relative) {
    return p.join(projectDir, ProjectPaths.assetsFolder, relative);
  }

  static Future<void> deleteExisting(String projectDir) async {
    final assets = Directory(
      p.join(projectDir, ProjectPaths.assetsFolder),
    );
    if (!await assets.exists()) return;
    await for (final entity in assets.list()) {
      if (entity is! File) continue;
      final name = p.basenameWithoutExtension(entity.path).toLowerCase();
      if (name != fileStem) continue;
      await entity.delete();
    }
  }

  /// Relative `cover.<ext>` currently on disk, or null when absent.
  static Future<String?> findExistingRelative(String projectDir) async {
    if (projectDir.isEmpty || projectDir.startsWith('memory://')) return null;
    final assets = Directory(
      p.join(projectDir, ProjectPaths.assetsFolder),
    );
    if (!await assets.exists()) return null;
    await for (final entity in assets.list()) {
      if (entity is! File) continue;
      if (p.basenameWithoutExtension(entity.path).toLowerCase() != fileStem) {
        continue;
      }
      final ext = p.extension(entity.path).replaceAll('.', '').toLowerCase();
      if (!allowedExtensions.contains(ext)) continue;
      return ProjectPaths.normalizeRelativeAssetPath(p.basename(entity.path));
    }
    return null;
  }

  /// Keeps [relative] when its file exists, else falls back to any `cover.*`.
  static Future<String?> resolveExistingRelative(
    String projectDir,
    String? relative,
  ) async {
    final trimmed = relative?.trim() ?? '';
    if (trimmed.isNotEmpty &&
        await File(absolutePath(projectDir, trimmed)).exists()) {
      return trimmed;
    }
    return findExistingRelative(projectDir);
  }

  /// Copies [sourcePath] into the project assets folder as `cover.{ext}`.
  /// Returns the relative path stored on [ProjectMeta.coverPath].
  static Future<String> importFromPath({
    required String projectDir,
    required String sourcePath,
  }) async {
    final ext = p.extension(sourcePath).replaceAll('.', '').toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw ArgumentError('不支持的图片格式');
    }
    return importFromBytes(
      projectDir: projectDir,
      bytes: await File(sourcePath).readAsBytes(),
      extension: ext,
    );
  }

  /// Writes [bytes] as `cover.{extension}` under the project assets folder.
  static Future<String> importFromBytes({
    required String projectDir,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (!allowedExtensions.contains(ext)) {
      throw ArgumentError('不支持的图片格式');
    }
    final assets = Directory(
      p.join(projectDir, ProjectPaths.assetsFolder),
    );
    await assets.create(recursive: true);
    await deleteExisting(projectDir);
    final relative = relativePath(ext);
    final dest = File(absolutePath(projectDir, relative));
    await dest.writeAsBytes(bytes, flush: true);
    return relative;
  }
}
