import 'dart:io';

import 'package:anoworld/foundation/fonts/file_system_font_repository.dart';
import 'package:anoworld/foundation/fonts/system_font.dart';
import 'package:anoworld/foundation/fonts/system_font_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imported fonts are listed and can be deleted', () async {
    final root = Directory.systemTemp.createTempSync('aw_fonts_test');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    final importedDir = Directory('${root.path}/imported');
    final repository = FileSystemFontRepository(
      catalog: _EmptyCatalog(),
      directories: const <Directory>[],
      importedFontsDirectory: () async => importedDir,
    );

    final source = File('${root.path}/MyFont.ttf')
      ..writeAsBytesSync([0, 1, 2, 3, 4]);

    final imported = await repository.importFont(source.path);
    expect(imported, isNotNull);
    expect(imported!.imported, isTrue);
    expect(await importedDir.exists(), isTrue);

    final listed = await repository.listFonts();
    expect(listed.any((f) => f.path == imported.path), isTrue);

    final deleted = await repository.deleteImportedFont(imported);
    expect(deleted, isTrue);
    expect(File(imported.path).existsSync(), isFalse);
  });
}

class _EmptyCatalog extends SystemFontCatalog {
  @override
  Future<List<SystemFont>> listFonts() async => const [];
}
