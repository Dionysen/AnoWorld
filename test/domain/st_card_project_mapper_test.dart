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

    final titles = draft.backgroundItems.map((e) => e.title).toList();
    expect(titles, containsAll(['情景', '开场素材', '客栈规矩']));
    expect(
      draft.backgroundItems.any((e) => e.value.body == '关掉的'),
      isFalse,
    );

    final project = draft.toProject(id: 'p_card');
    expect(project.meta.title, '掌柜');
    expect(project.cast.single.name, '掌柜');
    expect(project.background.entries.length, greaterThanOrEqualTo(3));
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
      draft.backgroundItems.any((e) => e.title.contains('情景')),
      isTrue,
    );
  });
}
