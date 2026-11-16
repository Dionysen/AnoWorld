import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/preset.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = StageResultMapper();

  test('maps background sections from fenced json', () {
    final background = mapper.backgroundFromRaw('''
```json
{"sections":[{"title":"世界观","body":"边城雨夜"}]}
```
''');
    expect(background.sections, hasLength(1));
    expect(background.sections.first.body, '边城雨夜');
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
    {"title": "荒野", "synopsis": "雨中独行", "exits": [{"to": "end", "kind": "default", "label": "天亮"}]}
  ]
}
''',
      cast: cast,
    );

    expect(main.nodes.length, greaterThanOrEqualTo(3));
    expect(main.beats, isEmpty);
    expect(main.edges, isNotEmpty);
    expect(main.edges.any((e) => e.kind == EdgeKind.branch), isTrue);

    final preset = Preset.builtinDefault();
    final project = Project(
      meta: ProjectMeta(
        id: 'p',
        title: 't',
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
      presets: [preset],
      activePresetId: preset.id,
      background: const Background(
        sections: [
          BackgroundSection(id: 'bg', title: '世界观', body: '边城'),
        ],
      ),
      cast: cast,
      main: main,
    );
    expect(const ProjectValidator().validate(project).hasErrors, isFalse);
  });

  test('throws on missing stations', () {
    expect(
      () => mapper.mainFromRaw('{"summary":"x","stations":[]}', cast: const []),
      throwsA(isA<StageMapException>()),
    );
  });
}
