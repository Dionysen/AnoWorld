import 'package:anoworld/domain/card_import/card_organize_mapper.dart';
import 'package:anoworld/domain/card_import/card_organize_models.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('split_world adds entry when body is substring', () {
    const mapper = CardOrganizeMapper();
    final draft = StCardImportDraft(
      title: '测试',
      castItems: [
        StCardImportItem(
          id: 'c1',
          sourceId: 'cast:c1',
          title: '甲',
          preview: '…',
          value: const CastMember(id: 'c1', name: '甲'),
        ),
      ],
      worldBookItems: [
        StCardImportItem(
          id: 'w1',
          sourceId: 'world:w1',
          title: '总设定',
          preview: '势力A 与 势力B',
          value: const WorldBookEntry(
            id: 'w1',
            title: '总设定',
            body: '势力A 与 势力B',
            alwaysOn: true,
          ),
        ),
      ],
    );

    const ops = [
      CardOrganizeOperation(
        op: 'split_world',
        fromSourceId: 'world:w1',
        entries: [
          CardOrganizeSplitEntry(
            title: '势力',
            body: '势力A',
            alwaysOn: true,
            keys: const [],
          ),
        ],
      ),
    ];

    final proposal = mapper.applyOperations(draft, ops);
    expect(proposal.draftAfter.worldBookItems.length, 2);
    expect(proposal.changes, isNotEmpty);
  });

  test('extract_to_cast appends substring to cast personality', () {
    const mapper = CardOrganizeMapper();
    final draft = StCardImportDraft(
      title: '测试',
      castItems: [
        StCardImportItem(
          id: 'c1',
          sourceId: 'cast:c1',
          title: '甲',
          preview: '…',
          value: const CastMember(id: 'c1', name: '甲'),
        ),
      ],
      worldBookItems: [
        StCardImportItem(
          id: 'w1',
          sourceId: 'world:w1',
          title: '总设定',
          preview: '势力A。甲：冷峻。',
          value: const WorldBookEntry(
            id: 'w1',
            title: '总设定',
            body: '势力A。甲：冷峻。',
            alwaysOn: true,
          ),
        ),
      ],
    );

    const ops = [
      CardOrganizeOperation(
        op: 'extract_to_cast',
        fromSourceId: 'world:w1',
        castItemId: 'c1',
        target: 'cast.personality',
        body: '甲：冷峻。',
      ),
    ];

    final proposal = mapper.applyOperations(draft, ops);
    expect(
      proposal.draftAfter.castItems.first.value.personality,
      contains('冷峻'),
    );
  });

  test('split_cast creates multiple cast from one world entry', () {
    const mapper = CardOrganizeMapper();
    final draft = StCardImportDraft(
      title: '测试',
      castItems: const [],
      worldBookItems: [
        StCardImportItem(
          id: 'w1',
          sourceId: 'world:w1',
          title: '人物集',
          preview: '…',
          value: const WorldBookEntry(
            id: 'w1',
            title: '人物集',
            body: '【甲】冷静。\n【乙】热情。',
            alwaysOn: true,
          ),
        ),
      ],
    );

    const ops = [
      CardOrganizeOperation(
        op: 'split_cast',
        fromSourceId: 'world:w1',
        castSlices: [
          CardOrganizeCastSlice(
            name: '甲',
            personality: '【甲】冷静。',
          ),
          CardOrganizeCastSlice(
            name: '乙',
            personality: '【乙】热情。',
          ),
        ],
      ),
    ];

    final proposal = mapper.applyOperations(draft, ops);
    expect(proposal.draftAfter.castItems.length, 2);
    expect(
      proposal.draftAfter.castItems.map((e) => e.value.name).toList(),
      containsAll(['甲', '乙']),
    );
  });

  test('rejects split when body is not substring', () {
    const mapper = CardOrganizeMapper();
    final draft = StCardImportDraft(
      title: '测试',
      castItems: const [],
      worldBookItems: [
        StCardImportItem(
          id: 'w1',
          sourceId: 'world:w1',
          title: '总设定',
          preview: '原文',
          value: const WorldBookEntry(
            id: 'w1',
            title: '总设定',
            body: '原文',
            alwaysOn: true,
          ),
        ),
      ],
    );

    const ops = [
      CardOrganizeOperation(
        op: 'split_world',
        fromSourceId: 'world:w1',
        entries: [
          CardOrganizeSplitEntry(
            title: '胡编',
            body: '完全新内容',
            alwaysOn: true,
            keys: const [],
          ),
        ],
      ),
    ];

    expect(
      () => mapper.applyOperations(draft, ops),
      throwsA(isA<CardOrganizeException>()),
    );
  });
}