import 'package:anoworld/domain/cast_extract/cast_extraction_models.dart';
import 'package:anoworld/domain/cast_extract/cast_merge.dart';
import 'package:anoworld/domain/cast_extract/cast_scan.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const roster = '''
## 主要人物
- 梦涵：苏氏商行掌柜，性格冷静。
  别名：苏姐
  台词：「价钱好谈，命不好谈。」
- 姬皓月：剑客。
''';

  test('gate drops names that never appear in the source', () {
    expect(
      gateExtractedCast(
        const ExtractedCast(name: '黑衣人', summary: '不存在的人'),
        roster,
      ),
      isNull,
    );
    expect(gateExtractedCast(const ExtractedCast(name: '梦涵'), roster)?.name,
        '梦涵');
  });

  test('gate keeps only literal aliases and example lines', () {
    final gated = gateExtractedCast(
      const ExtractedCast(
        name: '梦涵',
        aliases: <String>['苏姐', '不存在称号'],
        exampleLines: <String>['价钱好谈，命不好谈。', '编的台词'],
        summary: '{{char}}是掌柜，{{user}}的熟人',
      ),
      roster,
      playerName: '旅人',
    )!;
    expect(gated.aliases, <String>['苏姐']);
    expect(gated.exampleLines, <String>['价钱好谈，命不好谈。']);
    expect(gated.summary, '梦涵是掌柜，旅人的熟人');
  });

  test('gate caps overlong fields', () {
    final gated = gateExtractedCast(
      ExtractedCast(name: '梦涵', summary: '长' * 500),
      roster,
    )!;
    expect(gated.summary.length, 300);
  });

  test('merge only fills blanks and unions aliases', () {
    const existing = CastMember(
      id: 'c1',
      name: '梦涵',
      summary: '作者写的简介',
      aliases: <String>['掌柜'],
    );
    final candidates = buildCastMergeCandidates(
      extracted: const <ExtractedCast>[
        ExtractedCast(
          name: '梦涵',
          aliases: <String>['苏姐'],
          summary: 'AI 写的简介',
          personality: '冷静',
        ),
      ],
      existing: const <CastMember>[existing],
      newId: () => 'new',
    );
    expect(candidates, hasLength(1));
    final member = candidates.single.member;
    expect(candidates.single.isNew, isFalse);
    expect(member.id, 'c1');
    expect(member.summary, '作者写的简介');
    expect(member.personality, '冷静');
    expect(member.aliases, <String>['掌柜', '苏姐']);
  });

  test('merge dedupes the same character across entries', () {
    final candidates = buildCastMergeCandidates(
      extracted: const <ExtractedCast>[
        ExtractedCast(name: '梦涵', summary: '掌柜'),
        ExtractedCast(name: '苏姐', summary: '别称条目', aliases: <String>['梦涵']),
      ],
      existing: const <CastMember>[],
      newId: () => 'c1',
    );
    expect(candidates, hasLength(1));
    expect(candidates.single.member.summary, '掌柜');
  });

  test('scanner puts roster entries first and chunks long bodies', () {
    final book = WorldBook(
      entries: <WorldBookEntry>[
        WorldBookEntry(
          id: 'w_filler',
          title: '风土',
          body: '这里常年下雨。' * 80,
        ),
        const WorldBookEntry(
          id: 'w_people',
          title: '人物列表',
          body: '梦涵：掌柜。\n\n姬皓月：剑客。',
        ),
      ],
    );
    final scan = const CastScanner(maxWindowChars: 120).scan(book);
    expect(scan.windows.first.entryTitle, '人物列表');
    expect(scan.windows.length, greaterThan(2));
  });
}
