import 'package:anoworld/domain/ai/bridge_stream_parser.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = const ProjectFactory().createBlank(id: 'p', title: 't');
  final project = Project(
    meta: base.meta,
    worldBook: base.worldBook,
    cast: const <CastMember>[
      CastMember(id: 'c_lin', name: '林'),
    ],
    main: base.main,
  );

  test('only emits a line once its object closes', () {
    final parser = BridgeBeatStreamParser(project: project, beatId: 'b1');
    expect(
      parser.add('{"location":"雨夜","lines":[{"speaker":"林","text":"你来了'),
      isEmpty,
    );
    expect(parser.location, '雨夜');

    final first = parser.add('吗？"},');
    expect(first, hasLength(1));
    expect(first.single.text, '你来了吗？');
    expect(first.single.speakerId, 'c_lin');

    expect(parser.add('{"speaker":"旁白","text":"雨更大了"}'), hasLength(1));
    expect(parser.lines.last.speakerId, isNull);
    expect(parser.lines.last.kind, DialogueKind.narration);
  });

  test('handles escaped quotes and leading fences', () {
    final parser = BridgeBeatStreamParser(project: project, beatId: 'b1');
    final added = parser.add(
      '```json\n{"lines":[{"speaker":"林","text":"他说\\"走吧\\""}]}',
    );
    expect(added.single.text, '他说"走吧"');
  });

  test('maps the player alias onto the user speaker', () {
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      userAliases: const <String>['旅人'],
    );
    final added = parser.add(
      '{"lines":[{"speaker":"旅人","text":"我跟着你"}]}',
    );
    expect(added.single.speakerId, kPlayUserSpeakerId);
  });

  test('skips rows without text instead of stalling', () {
    final parser = BridgeBeatStreamParser(project: project, beatId: 'b1');
    expect(parser.add('{"lines":[{"speaker":"林","text":""},'), isEmpty);
    final added = parser.add('{"speaker":"林","text":"继续"}');
    expect(added.single.text, '继续');
  });

  test('stops at the end of the lines array', () {
    final parser = BridgeBeatStreamParser(project: project, beatId: 'b1');
    final added = parser.add(
      '{"lines":[{"speaker":"林","text":"一"}],'
      '"choices":[{"text":"{\\"type\\":\\"end\\"}","target":{}}]}',
    );
    expect(added, hasLength(1));
    expect(parser.lines, hasLength(1));
  });
}
