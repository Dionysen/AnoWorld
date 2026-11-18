import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy sections[] maps to always-on entries', () {
    final worldBook = WorldBook.fromJson({
      'sections': [
        {'id': 's1', 'title': '世界观', 'body': '边城雨夜'},
      ],
    });
    expect(worldBook.entries, hasLength(1));
    expect(worldBook.entries.first.alwaysOn, isTrue);
    expect(worldBook.entries.first.body, '边城雨夜');
  });

  test('round-trip entries json', () {
    const original = WorldBook(
      entries: [
        WorldBookEntry(
          id: 'a',
          title: '基调',
          body: '世界',
          alwaysOn: true,
        ),
        WorldBookEntry(
          id: 'b',
          title: '地点',
          body: '客栈',
          keys: const ['客栈'],
        ),
      ],
    );
    final restored = WorldBook.fromJson(original.toJson());
    expect(restored.entries.length, original.entries.length);
    expect(restored.entries[1].keys, ['客栈']);
  });

  test('Project reads legacy background json key', () {
    final project = Project.fromJson({
      'meta': {
        'id': 'p',
        'title': 't',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      },
      'background': {
        'entries': [
          {
            'id': 'wb1',
            'title': '世界',
            'body': '边城',
            'keys': <String>[],
            'alwaysOn': true,
          },
        ],
      },
      'cast': <dynamic>[],
      'main': {
        'summary': '',
        'startNodeId': 'n0',
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
        'beats': <dynamic>[],
      },
    });
    expect(project.worldBook.entries.single.body, '边城');
    expect(project.toJson().containsKey('worldBook'), isTrue);
  });
}