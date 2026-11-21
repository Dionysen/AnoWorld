import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/project/project_paths.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Zip codec for a full story package folder (`manifest` + `project.json` + `assets/`).
class ProjectPackageArchive {
  ProjectPackageArchive._();

  static const String fileExtension = 'anoworld';

  /// Zip [directory] contents (not the directory name itself).
  static Future<Uint8List> zipDirectory(String directory) async {
    final root = Directory(directory);
    if (!await root.exists()) {
      throw ProjectIoException('故事包目录不存在');
    }
    final archive = Archive();
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: directory);
      final name = relative.replaceAll('\\', '/');
      if (name.isEmpty || name.endsWith('/')) continue;
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    if (archive.isEmpty) {
      throw ProjectIoException('故事包是空的');
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Extract [bytes] into [destinationDirectory], creating it if needed.
  static Future<void> unzipTo({
    required Uint8List bytes,
    required String destinationDirectory,
  }) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw ProjectIoException('不是有效的故事包文件');
    }
    if (archive.isEmpty) {
      throw ProjectIoException('故事包是空的');
    }
    final dest = Directory(destinationDirectory);
    await dest.create(recursive: true);
    for (final entry in archive) {
      final name = entry.name.replaceAll('\\', '/');
      if (name.isEmpty || name.contains('..')) continue;
      final outPath = p.join(destinationDirectory, name);
      if (entry.isDirectory || name.endsWith('/')) {
        await Directory(outPath).create(recursive: true);
        continue;
      }
      final data = entry.readBytes() ?? Uint8List(0);
      await File(outPath).parent.create(recursive: true);
      await File(outPath).writeAsBytes(data, flush: true);
    }
  }

  /// Locate `manifest.json` at the extract root or one nested folder.
  static Future<String> findPackageRoot(String extractedDirectory) async {
    final direct = File(
      p.join(extractedDirectory, ProjectPaths.manifestFileName),
    );
    if (await direct.exists()) return extractedDirectory;

    final root = Directory(extractedDirectory);
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final nested = File(
        p.join(entity.path, ProjectPaths.manifestFileName),
      );
      if (await nested.exists()) return entity.path;
    }
    throw ProjectIoException('文件里没有完整的故事包');
  }
}
