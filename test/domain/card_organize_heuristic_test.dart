import 'package:anoworld/domain/card_import/card_organize_heuristic.dart';
import 'package:anoworld/domain/card_import/card_organize_mapper.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('heuristic split_cast for 【名】 blocks', () {
    const heuristic = CardOrganizeHeuristic();
    final draft = StCardImportDraft(
      title: 't',
      castItems: const [],
      worldBookItems: [
        StCardImportItem(
          id: 'w1',
          sourceId: 'world:w1',
          title: '人物',
          preview: '…',
          value: const WorldBookEntry(
            id: 'w1',
            title: '人物',
            body: '【甲】冷静寡言。\n\n【乙】热心健谈。',
            alwaysOn: true,
          ),
        ),
      ],
    );
    final ops = heuristic.buildOperations(draft);
    expect(ops, isNotEmpty);
    const mapper = CardOrganizeMapper();
    final proposal = mapper.applyOperations(draft, ops);
    expect(proposal.draftAfter.castItems.length, 2);
  });

  test('heuristic ignores stat sheet colons', () {
    const heuristic = CardOrganizeHeuristic();
    final draft = StCardImportDraft(
      title: 't',
      castItems: const [],
      worldBookItems: [
        StCardImportItem(
          id: 'w1',
          sourceId: 'world:w1',
          title: '规则',
          preview: '…',
          value: const WorldBookEntry(
            id: 'w1',
            title: '规则',
            body: '骰子：1d20\n位置：客栈\n时间：黄昏',
            alwaysOn: true,
          ),
        ),
      ],
    );
    expect(heuristic.buildOperations(draft), isEmpty);
  });
}