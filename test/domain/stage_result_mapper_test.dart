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

  test('maps short main into playable story', () {
    final cast = const [
      CastMember(id: 'c_0', name: '少年', summary: '旅人'),
      CastMember(id: 'c_1', name: '掌柜', summary: '老板'),
    ];
    final main = mapper.mainFromRaw(
      '''
{
  "summary": "雨夜投宿",
  "scenes": [
    {
      "title": "城门",
      "synopsis": "离开",
      "location": "城门",
      "speakers": ["少年"],
      "lines": [{"speaker": "少年", "text": "该走了。"}]
    },
    {
      "title": "客栈",
      "synopsis": "投宿",
      "location": "客栈",
      "speakers": ["少年", "掌柜"],
      "lines": [{"speaker": "掌柜", "text": "留宿？"}],
      "choices": [
        {"text": "住下", "end": true},
        {"text": "再看看", "stay": true}
      ]
    }
  ]
}
''',
      cast: cast,
    );

    expect(main.nodes, hasLength(2));
    expect(main.edges, hasLength(1));
    expect(main.beats.last.choices, hasLength(2));
    expect(main.beats.last.choices.first.target.type, TransitionType.end);
    expect(main.beats.first.lines.first.speakerId, 'c_0');

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

  test('throws on missing scenes', () {
    expect(
      () => mapper.mainFromRaw('{"summary":"x","scenes":[]}', cast: const []),
      throwsA(isA<StageMapException>()),
    );
  });
}
