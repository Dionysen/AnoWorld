import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/models/project_asset.dart';
import 'package:path/path.dart' as p;

/// Writes generated / imported images under `assets/` and builds catalog rows.
abstract final class ProjectAssetFiles {
  static String absolutePath(String projectDir, String relative) {
    return p.join(projectDir, ProjectPaths.assetsFolder, relative);
  }

  /// Resolves a catalog asset to a local file when present on disk.
  static File? tryFile({
    required String projectDir,
    required ProjectAsset? asset,
  }) {
    if (asset == null) return null;
    final file = File(absolutePath(projectDir, asset.relativePath));
    if (!file.existsSync()) return null;
    return file;
  }

  static Future<ProjectAsset> writePng({
    required String projectDir,
    required String assetId,
    required ProjectAssetKind kind,
    required String relativePath,
    required Uint8List bytes,
  }) async {
    final relative = ProjectPaths.normalizeRelativeAssetPath(relativePath);
    final dest = File(absolutePath(projectDir, relative));
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes, flush: true);
    return ProjectAsset(id: assetId, kind: kind, relativePath: relative);
  }

  static String avatarRelativePath(String castId) =>
      ProjectPaths.normalizeRelativeAssetPath('avatars/$castId.png');

  static String backgroundRelativePath(String nodeId) =>
      ProjectPaths.normalizeRelativeAssetPath('backgrounds/$nodeId.png');

  static String spriteRelativePath(String castId) =>
      ProjectPaths.normalizeRelativeAssetPath('sprites/$castId.png');
}
