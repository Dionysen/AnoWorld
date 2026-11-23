import 'package:anoworld/domain/ai/bridge_stream_parser.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = const ProjectFactory().createBlank(id: 'p', title: 't');
  final project = Project(
    meta: base.meta,
    worldBook: base.worldBook,
    cast: const <CastMember>[
      CastMember(id: 'c_lin', name: '林'),
      CastMember(id: 'c_me', name: '旅人'),
    ],
    main: base.main,
  );
  const role = PlayRole(playerCastId: 'c_me', aliases: <String>['我']);

  test('only emits a line once its object closes', () {
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      role: role,
    );
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
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      role: role,
    );
    final added = parser.add(
      '```json\n{"lines":[{"speaker":"林","text":"他说\\"走吧\\""}]}',
    );
    expect(added.single.text, '他说"走吧"');
  });

  test('maps the player role and aliases onto the player member', () {
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      role: role,
    );
    final added = parser.add(
      '{"lines":[{"speaker":"我","text":"我跟着你"}]}',
    );
    expect(added.single.speakerId, 'c_me');
    expect(added.single.kind, DialogueKind.speech);
  });

  test('unknown speaker falls back to narration', () {
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      role: role,
    );
    final added = parser.add(
      '{"lines":[{"speaker":"黑衣人","text":"站住"}]}',
    );
    expect(added.single.speakerId, isNull);
    expect(added.single.kind, DialogueKind.narration);
  });

  test('recovers a cast speaker from a leading label', () {
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      role: role,
    );
    final added = parser.add(
      '{"lines":[{"speaker":"旁白","text":"林：进来吧"}]}',
    );
    expect(added.single.speakerId, 'c_lin');
    expect(added.single.text, '进来吧');
  });

  test('skips rows without text instead of stalling', () {
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      role: role,
    );
    expect(parser.add('{"lines":[{"speaker":"林","text":""},'), isEmpty);
    final added = parser.add('{"speaker":"林","text":"继续"}');
    expect(added.single.text, '继续');
  });

  test('stops at the end of the lines array', () {
    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: 'b1',
      role: role,
    );
    final added = parser.add(
      '{"lines":[{"speaker":"林","text":"一"}],'
      '"choices":[{"text":"{\\"type\\":\\"end\\"}","target":{}}]}',
    );
    expect(added, hasLength(1));
    expect(parser.lines, hasLength(1));
  });
}
