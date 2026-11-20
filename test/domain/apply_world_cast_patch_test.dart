import 'package:anoworld/domain/main/apply_cast_patch.dart';
import 'package:anoworld/domain/main/apply_world_book_patch.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('world upsert and remove', () {
    const base = WorldBook(
      entries: [
        WorldBookEntry(id: 'w1', title: '旧', body: '旧文', alwaysOn: true),
      ],
    );
    final next = const ApplyWorldBookPatch().apply(base, [
      {
        'op': 'upsert_entry',
        'id': 'w1',
        'title': '新标题',
        'body': '新正文',
        'alwaysOn': true,
      },
      {
        'op': 'upsert_entry',
        'title': '加一条',
        'body': '内容',
      },
    ]);
    expect(next.entries, hasLength(2));
    expect(next.entries.firstWhere((e) => e.id == 'w1').title, '新标题');
  });

  test('cast upsert and remove', () {
    final base = [
      const CastMember(id: 'c1', name: '甲', summary: '旧'),
    ];
    final next = const ApplyCastPatch().apply(base, [
      {
        'op': 'upsert_member',
        'id': 'c1',
        'name': '甲',
        'summary': '新简介',
      },
      {
        'op': 'upsert_member',
        'name': '乙',
        'summary': '配角',
      },
    ]);
    expect(next, hasLength(2));
    expect(next.firstWhere((c) => c.id == 'c1').summary, '新简介');
  });
}
