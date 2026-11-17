import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/create/character_card_import_page.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(project.background.entries, isNotEmpty);
    expect(
      project.background.entries.any((e) => e.title == '情景'),
      isTrue,
    );
  });
}
