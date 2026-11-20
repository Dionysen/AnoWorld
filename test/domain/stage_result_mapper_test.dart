import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = StageResultMapper();

  test('maps world book sections from fenced json', () {
    final worldBook = mapper.worldBookFromRaw('''
```json
{"sections":[{"title":"世界观","body":"边城雨夜"}]}
```
''');
    expect(worldBook.entries, hasLength(1));
    expect(worldBook.entries.first.body, '边城雨夜');
    expect(worldBook.entries.first.alwaysOn, isTrue);
  });

  test('maps cast list', () {
    final cast = mapper.castFromRaw(
      '{"cast":[{"name":"少年","summary":"旅人"},{"name":"掌柜","summary":"老板"}]}',
    );
    expect(cast.map((c) => c.name), ['少年', '掌柜']);
  });

  test('maps skeleton main without dialogue beats', () {
    final cast = const [
      CastMember(id: 'c_0', name: '少年', summary: '旅人'),
      CastMember(id: 'c_1', name: '掌柜', summary: '老板'),
    ];
    final main = mapper.mainFromRaw(
      '''
{
  "summary": "雨夜投宿",
  "stations": [
    {"title": "城门", "synopsis": "决心离开", "exits": [{"to": "客栈", "kind": "default"}, {"to": "荒野", "kind": "branch", "label": "不投宿"}]},
    {"title": "客栈", "synopsis": "与掌柜周旋", "exits": [{"to": "end", "kind": "default", "label": "住下"}]},
    {"title": "荒野", "synopsis": "雨中独行", "exits": []}
  ]
}
''',
      cast: cast,
    );

    expect(main.nodes.length, greaterThanOrEqualTo(3));
    expect(main.beats, isEmpty);
    expect(main.edges, isNotEmpty);
    expect(main.edges.any((e) => e.kind == EdgeKind.branch), isTrue);
    // Open leaf stays without auto-wired ending.
    final wild = main.nodes.firstWhere((n) => n.title == '荒野');
    expect(main.edges.any((e) => e.from == wild.id), isFalse);

    final project = Project(
      meta: ProjectMeta(
        id: 'p',
        title: 't',
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
      worldBook: const WorldBook(
        entries: [
          WorldBookEntry(
            id: 'bg',
            title: '世界观',
            body: '边城',
            alwaysOn: true,
          ),
        ],
      ),
      cast: cast,
      main: main,
    );
    expect(const ProjectValidator().validate(project).hasErrors, isFalse);
  });

  test('enforceMinStations rejects short full graphs', () {
    expect(
      () => mapper.mainFromRaw(
        '''
{"summary":"短","stations":[
{"title":"a","synopsis":"一","exits":[{"to":"b","kind":"default"}]},
{"title":"b","synopsis":"二","exits":[]}
]}
''',
        cast: const [],
        enforceMinStations: true,
      ),
      throwsA(isA<StageMapException>()),
    );
  });

  test('throws on missing stations', () {
    expect(
      () => mapper.mainFromRaw('{"summary":"x","stations":[]}', cast: const []),
      throwsA(isA<StageMapException>()),
    );
  });

  test('maps edge detail from stations and top-level edges', () {
    final main = mapper.mainFromRaw(
      '''
{"summary":"雨夜",
 "stations":[
  {"title":"城门","synopsis":"决心离开","exits":[
    {"to":"客栈","kind":"default","detail":"冒着雨走过去"},
    {"to":"荒野","kind":"branch","label":"不投宿","detail":"一路淋到天亮"}]},
  {"title":"客栈","synopsis":"与掌柜周旋","exits":[
    {"to":"荒野","kind":"default","detail":"被赶出来"}]},
  {"title":"荒野","synopsis":"雨中独行","exits":[]}
 ],
 "edges":[{"from":"荒野","to":"end","kind":"default","label":"倒下","detail":"故事在此收束"}]}
''',
      cast: const [],
    );

    final details = main.edges.map((e) => e.detail).toList(growable: false);
    expect(details, contains('冒着雨走过去'));
    expect(details, contains('一路淋到天亮'));
    expect(details, contains('被赶出来'));
    expect(details, contains('故事在此收束'));
  });
}
