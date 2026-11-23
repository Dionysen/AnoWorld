import 'dart:typed_data';

import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/card_import/st_character_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = StCardProjectMapper();

  test('maps card fields into cast / background', () {
    final draft = mapper.fromCards([
      const StCharacterCard(
        name: '掌柜',
        description: '客栈老板',
        personality: '精明',
        scenario: '雨夜客栈',
        firstMes: '哟，投宿？',
        mesExample: '{{user}}: 有房吗\n{{char}}: 有。',
        systemPrompt: '少系统腔',
        bookEntries: [
          StCharacterBookEntry(
            name: '客栈规矩',
            content: '雨夜只收现银',
            keys: ['客栈'],
          ),
          StCharacterBookEntry(
            content: '关掉的',
            enabled: false,
          ),
        ],
      ),
    ]);

    expect(draft.title, '掌柜');
    expect(draft.castItems, hasLength(1));
    expect(draft.castItems.first.value.summary, '客栈老板');
    expect(draft.castItems.first.value.isProtagonist, isTrue);
    expect(draft.castItems.first.value.exampleLines, isNotEmpty);

    final titles = draft.worldBookItems.map((e) => e.title).toList();
    expect(titles, containsAll(['情景', '开场素材', '客栈规矩']));
    final disabled = draft.worldBookItems.where((e) => e.value.body == '关掉的');
    expect(disabled, hasLength(1));
    expect(disabled.single.included, isFalse);

    final project = draft.toProject(id: 'p_card');
    expect(project.meta.title, '掌柜');
    expect(project.cast.single.name, '掌柜');
    expect(project.worldBook.entries.length, greaterThanOrEqualTo(3));
    expect(draft.cardAiNote, contains('少系统腔'));
  });

  test('second card becomes extra cast member', () {
    final draft = mapper.fromCards(const [
      StCharacterCard(name: '主角', description: '旅人'),
      StCharacterCard(name: '配角', description: '向导', scenario: '山路'),
    ]);
    expect(draft.castItems.map((e) => e.title), ['主角', '配角']);
    expect(draft.castItems.first.value.isProtagonist, isTrue);
    expect(draft.castItems.last.value.isProtagonist, isFalse);
    expect(
      draft.worldBookItems.any((e) => e.title.contains('情景')),
      isTrue,
    );
  });

  test('keeps first png cover bytes on draft', () {
    final cover = Uint8List.fromList(const [1, 2, 3]);
    final draft = mapper.fromCards([
      StCharacterCard(
        name: '有图',
        coverImageBytes: cover,
      ),
      const StCharacterCard(name: '无图'),
    ]);
    expect(draft.coverImageBytes, same(cover));
  });

  test('disabled book entries stay listed but unchecked', () {
    final draft = mapper.fromCards(const [
      StCharacterCard(
        name: '甲',
        bookEntries: [
          StCharacterBookEntry(content: '开着的'),
          StCharacterBookEntry(content: '关掉的', enabled: false),
        ],
      ),
    ]);

    final off = draft.worldBookItems.singleWhere(
      (e) => e.value.body == '关掉的',
    );
    expect(off.included, isFalse);
    expect(
      draft.toProject(id: 'p_off').worldBook.entries.any(
            (e) => e.body == '关掉的',
          ),
      isFalse,
    );
  });

  test('keeps up to 50 example lines from mes_example', () {
    final raw = List.generate(60, (i) => 'L$i').join('\n');
    final draft = mapper.fromCards([
      StCharacterCard(name: '乙', mesExample: raw),
    ]);
    final lines = draft.castItems.first.value.exampleLines;
    expect(lines, hasLength(StCardProjectMapper.maxExampleLines));
    expect(lines.last, 'L49');
  });

  test('carries card metadata onto the story', () {
    final draft = mapper.fromCards(const [
      StCharacterCard(
        name: '掌柜',
        creator: '阿福',
        characterVersion: '1.2',
        creatorNotes: '原作者注',
        tags: ['古风', '客栈'],
      ),
    ]);

    expect(draft.cardMeta.creator, '阿福');
    final project = draft.toProject(id: 'p_meta');
    expect(project.meta.card.creator, '阿福');
    expect(project.meta.card.version, '1.2');
    expect(project.meta.card.creatorNotes, '原作者注');
    expect(project.meta.card.tags, ['古风', '客栈']);
  });
}
