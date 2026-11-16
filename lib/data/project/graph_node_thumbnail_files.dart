import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// PNG thumbnails for main-graph nodes (`assets/graph_nodes/{id}.png`).
abstract final class GraphNodeThumbnailFiles {
  static const String folderName = 'graph_nodes';

  static String directory(String projectDir) =>
      p.join(projectDir, 'assets', folderName);

  static String filePath(String projectDir, String nodeId) =>
      p.join(directory(projectDir), '$nodeId.png');

  static Future<void> write(
    String projectDir,
    String nodeId,
    Uint8List png,
  ) async {
    final dir = Directory(directory(projectDir));
    await dir.create(recursive: true);
    await File(filePath(projectDir, nodeId)).writeAsBytes(png, flush: true);
  }

  static Future<Uint8List?> read(String projectDir, String nodeId) async {
    final file = File(filePath(projectDir, nodeId));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<void> delete(String projectDir, String nodeId) async {
    final file = File(filePath(projectDir, nodeId));
    if (await file.exists()) await file.delete();
  }

  static Future<Map<String, Uint8List>> readAll(String projectDir) async {
    final dir = Directory(directory(projectDir));
    if (!await dir.exists()) return {};
    final out = <String, Uint8List>{};
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.png')) continue;
      final id = p.basenameWithoutExtension(entity.path);
      out[id] = await entity.readAsBytes();
    }
    return out;
  }
}