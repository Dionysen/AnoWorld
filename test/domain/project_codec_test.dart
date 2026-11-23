import 'dart:convert';
import 'dart:io';

import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project JSON codec', () {
    test('ignores legacy v1 preset fields on read', () {
      final raw = File('test/fixtures/rain_night_project.json').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['presets'] = [
        {
          'id': 'preset_legacy',
          'name': 'legacy',
          'styleNotes': 'should drop',
        },
      ];
      map['activePresetId'] = 'preset_legacy';
      final project = Project.fromJson(map);
      expect(project.toJson().containsKey('presets'), isFalse);
      expect(project.toJson().containsKey('activePresetId'), isFalse);
    });

    test('fixture round-trips without changing semantics', () {
      final raw = File('test/fixtures/rain_night_project.json').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final project = Project.fromJson(map);
      final again = Project.fromJson(
        jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>,
      );

      expect(again.meta.id, 'proj_rain_night');
      expect(again.meta.title, '雨夜投宿');
      expect(again.main.startNodeId, 'n1');
      expect(again.main.nodes, hasLength(2));
      expect(again.main.beats, hasLength(2));
      expect(again.cast.map((c) => c.id), <String>['c_hero', 'c_keeper']);
      expect(again.main.beatById('b2')!.choices, hasLength(2));
      expect(again.main.beatById('b2')!.choices[0].target.type.name, 'end');
    });

    test('card metadata round-trips and stays out of the file when empty', () {
      final project = const ProjectFactory().createBlank(
        id: 'p_card',
        title: '卡片',
        now: DateTime.utc(2026, 1, 1),
      );
      expect(project.toJson()['meta'].containsKey('card'), isFalse);

      final withCard = project.copyWith(
        meta: project.meta.copyWith(
          card: const StoryCardMeta(
            creator: '阿福',
            version: '1.2',
            creatorNotes: '原作者注',
            tags: <String>['古风', '客栈'],
          ),
        ),
      );
      final decoded = Project.fromJson(
        jsonDecode(jsonEncode(withCard.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.meta.card.creator, '阿福');
      expect(decoded.meta.card.version, '1.2');
      expect(decoded.meta.card.creatorNotes, '原作者注');
      expect(decoded.meta.card.tags, <String>['古风', '客栈']);
    });

    test('factory sample matches MainBeat linear example', () {
      final project = const ProjectFactory().createRainNightSample(
        now: DateTime.utc(2026, 1, 1),
      );
      final encoded = project.toJson();
      final decoded = Project.fromJson(
        jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>,
      );

      expect(decoded.main.summary, '少年离家，雨夜投宿。');
      expect(decoded.main.edges.single.kind.name, 'defaultEdge');
      expect(decoded.main.nodes.first.beatIds, <String>['b1']);
    });
  });

  group('ProjectValidator', () {
    test('rain night sample is playable', () {
      final project = const ProjectFactory().createRainNightSample(
        now: DateTime.utc(2026, 1, 1),
      );
      final result = const ProjectValidator().validate(project);
      expect(result.errors, isEmpty);
      expect(result.isPlayable, isTrue);
    });

    test('blank project is playable', () {
      final project = const ProjectFactory().createBlank(
        id: 'p_blank',
        title: '空白',
        now: DateTime.utc(2026, 1, 1),
      );
      final result = const ProjectValidator().validate(project);
      expect(result.errors, isEmpty);
      expect(result.isPlayable, isTrue);
      expect(
        result.issues.map((e) => e.code),
        contains('node_open_interval'),
      );
    });

    test('missing start node is an error', () {
      final project = const ProjectFactory().createBlank(
        id: 'p_bad',
        title: '坏',
        now: DateTime.utc(2026, 1, 1),
      );
      final broken = project.copyWith(
        main: project.main.copyWith(startNodeId: 'missing'),
      );
      final result = const ProjectValidator().validate(broken);
      expect(
        result.errors.map((e) => e.code),
        contains('start_node_missing'),
      );
    });
  });
}
