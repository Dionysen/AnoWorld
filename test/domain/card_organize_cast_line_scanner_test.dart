import 'package:anoworld/domain/card_import/card_organize_cast_line_scanner.dart';
import 'package:anoworld/domain/card_import/card_organize_heuristic.dart';
import 'package:anoworld/domain/card_import/card_organize_mapper.dart';
import 'package:anoworld/domain/card_import/card_organize_name_anchor.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nestedRoster = '''
苍玄界人物志:
  注:下面人物
  大雍皇朝:
    成员:
      姬皓月: 昭武女帝, 中州大雍皇朝的统治者。
      姬灵均: 皇朝国师, 女帝之姑。
      萧衍: 天剑圣地的定海神针。
      梦涵: 天剑圣地圣女。
''';

  const bracketStyle = '''
【甲】冷静寡言。

【乙】热心健谈。
''';

  const markdownStyle = '''
### 艾伦
沉默的佣兵，只信双手。

### 贝拉
爱打趣却心很软。
''';

  test('scanner: nested name lines', () {
    final lines = CardOrganizeCastLineScanner.scan(nestedRoster);
    expect(lines.map((e) => e.name).toList(), containsAll(['姬皓月', '梦涵']));
    expect(lines.map((e) => e.name), isNot(contains('基础属性')));
    expect(lines.map((e) => e.name), isNot(contains('成员')));
  });

  test('anchor detects brackets and headings', () {
    expect(CardOrganizeNameAnchor.isAnchoredInSource('甲', bracketStyle), isTrue);
    expect(
      CardOrganizeNameAnchor.isAnchoredInSource('艾伦', markdownStyle),
      isTrue,
    );
    expect(
      CardOrganizeNameAnchor.isAnchoredInSource('基础属性', '基础属性: 力量'),
      isTrue,
    );
  });

  test('heuristic: bracket blocks', () {
    const heuristic = CardOrganizeHeuristic();
    final draft = _draft('人物', bracketStyle);
    final ops = heuristic.buildOperations(draft);
    expect(ops, isNotEmpty);
    const mapper = CardOrganizeMapper();
    expect(mapper.applyOperations(draft, ops).draftAfter.castItems.length, 2);
  });

  test('heuristic: markdown headings', () {
    const heuristic = CardOrganizeHeuristic();
    final draft = _draft('小队', markdownStyle);
    final ops = heuristic.buildOperations(draft);
    expect(ops, isNotEmpty);
    final names = CardOrganizeMapper()
        .applyOperations(draft, ops)
        .draftAfter
        .castItems
        .map((e) => e.value.name)
        .toSet();
    expect(names, containsAll(['艾伦', '贝拉']));
  });

  test('heuristic ignores stat field lines', () {
    const heuristic = CardOrganizeHeuristic();
    final draft = _draft(
      '规则',
      '骰子：1d20\n位置：客栈\n时间：黄昏',
    );
    expect(heuristic.buildOperations(draft), isEmpty);
  });
}

StCardImportDraft _draft(String title, String body) {
  return StCardImportDraft(
    title: 't',
    castItems: const [],
    worldBookItems: [
      StCardImportItem(
        id: 'w1',
        sourceId: 'world:w1',
        title: title,
        preview: '…',
        value: WorldBookEntry(
          id: 'w1',
          title: title,
          body: body,
          alwaysOn: true,
        ),
      ),
    ],
  );
}