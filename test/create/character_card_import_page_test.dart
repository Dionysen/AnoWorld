import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/create/character_card_import_page.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/project/project_cover_files.dart';
import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/card_import/st_character_card_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/test_app.dart';

void main() {
  testWidgets('imports json card into project hub material', (tester) async {
    final repo = MemoryProjectRepository(idGenerator: () => 'p_from_card');
    final json = jsonEncode({
      'spec': 'chara_card_v3',
      'data': {
        'name': '掌柜',
        'description': '客栈老板',
        'personality': '精明',
        'scenario': '雨夜客栈',
        'first_mes': '哟，投宿？',
        'character_book': {
          'entries': [
            {
              'name': '规矩',
              'content': '只收现银',
              'keys': ['规矩'],
              'constant': true,
              'enabled': true,
            },
          ],
        },
      },
    });

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: CharacterCardImportPage(
          pickCardFiles: () async => [
            PickedCharacterCardFile(
              name: 'keeper.json',
              bytes: Uint8List.fromList(utf8.encode(json)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择角色卡'));
    await tester.pumpAndSettle();

    expect(find.text('掌柜'), findsWidgets);
    expect(find.text('情景'), findsOneWidget);
    expect(find.text('开场素材'), findsOneWidget);
    expect(find.text('规矩'), findsOneWidget);

    final write = find.text('写入故事');
    await tester.ensureVisible(write);
    await tester.pumpAndSettle();
    await tester.tap(write);
    await tester.pumpAndSettle();

    expect(find.byType(CreateHubPage), findsOneWidget);
    final project = await repo.open('p_from_card');
    expect(project.cast.single.name, '掌柜');
    expect(project.worldBook.entries, isNotEmpty);
    expect(
      project.worldBook.entries.any((e) => e.title == '情景'),
      isTrue,
    );
  });

  test('png card cover lands in project assets on write', () async {
    final tempRoot = await Directory.systemTemp.createTemp('aw_card_cover_');
    addTearDown(() async {
      if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
    });
    final paths = ProjectPaths(documentsDirectory: () async => tempRoot);
    paths.seedLibraryRoot(p.join(tempRoot.path, 'AnoWorld'));
    final repo = FolderProjectRepository(
      paths: paths,
      idGenerator: () => 'p_from_png',
    );

    final json = jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': 'PNG角色',
        'description': '从图片来',
        'scenario': '城门',
      },
    });
    final payload = base64Encode(utf8.encode(json));
    final png = _minimalPngWithText('chara', payload);
    const parser = StCharacterCardParser();
    const mapper = StCardProjectMapper();
    final draft = mapper.fromCards([
      parser.parsePngBytes(png, sourceLabel: 'char.png'),
    ]);
    expect(draft.coverImageBytes, isNotNull);

    final created = await repo.create(title: draft.title);
    var filled = draft.toProject(id: created.meta.id);
    await repo.save(filled);
    final projectDir = await repo.directoryFor(filled.meta.id);
    expect(projectDir, isNotNull);
    final relative = await ProjectCoverFiles.importFromBytes(
      projectDir: projectDir!,
      bytes: draft.coverImageBytes!,
      extension: 'png',
    );
    filled = filled.copyWith(
      meta: filled.meta.copyWith(coverPath: relative),
    );
    await repo.save(filled);

    final project = await repo.open('p_from_png');
    expect(project.meta.coverPath, 'cover.png');
    expect(
      await File(p.join(projectDir, 'assets', 'cover.png')).readAsBytes(),
      png,
    );
  });
}

Uint8List _minimalPngWithText(String keyword, String value) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  final keywordBytes = latin1.encode(keyword);
  final valueBytes = latin1.encode(value);
  final data = [...keywordBytes, 0, ...valueBytes];
  final type = ascii.encode('tEXt');
  final length = data.length;
  final iendType = ascii.encode('IEND');
  return Uint8List.fromList([
    ...signature,
    (length >> 24) & 0xFF,
    (length >> 16) & 0xFF,
    (length >> 8) & 0xFF,
    length & 0xFF,
    ...type,
    ...data,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    ...iendType,
    0,
    0,
    0,
    0,
  ]);
}
