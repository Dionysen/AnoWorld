import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/play_history.dart';
import 'package:flutter_test/flutter_test.dart';

MainSavePointer _at(String beatId, int lineIndex, {String phase = 'lines'}) =>
    MainSavePointer(
      nodeId: 'n1',
      beatId: beatId,
      lineIndex: lineIndex,
      phase: phase,
    );

void main() {
  test('records positions and steps back / forward', () {
    final history = PlayHistory()
      ..record(_at('b1', 0))
      ..record(_at('b1', 1))
      ..record(_at('b2', 0));

    expect(history.cursor, 2);
    expect(history.canBack, isTrue);
    expect(history.canForward, isFalse);
    expect(history.atLatest, isTrue);

    expect(history.stepBack()?.beatId, 'b1');
    expect(history.cursor, 1);
    expect(history.canForward, isTrue);
    expect(history.atLatest, isFalse);

    expect(history.stepForward()?.beatId, 'b2');
    expect(history.cursor, 2);
    expect(history.canForward, isFalse);
  });

  test('replaying forward reuses entries instead of duplicating', () {
    final history = PlayHistory()
      ..record(_at('b1', 0))
      ..record(_at('b1', 1))
      ..record(_at('b2', 0));

    history.stepBack();
    history.stepBack();
    history.record(_at('b1', 1));
    expect(history.entries, hasLength(3));
    expect(history.cursor, 1);

    history.record(_at('b2', 0));
    expect(history.entries, hasLength(3));
    expect(history.cursor, 2);
  });

  test('a new destination truncates forward entries', () {
    final history = PlayHistory()
      ..record(_at('b1', 0))
      ..record(_at('b1', 1))
      ..record(_at('b2', 0));

    history.stepBack();
    history.record(_at('b3', 0));
    expect(history.entries.map((e) => e.beatId), ['b1', 'b1', 'b3']);
    expect(history.cursor, 2);
    expect(history.canForward, isFalse);
  });

  test('jumpToLatest lands on the newest progress', () {
    final history = PlayHistory()
      ..record(_at('b1', 0))
      ..record(_at('b1', 1))
      ..record(_at('b2', 0));
    history.jumpToLatest();
    expect(history.cursor, 2);
    expect(history.jumpToLatest(), isNull);

    history.stepBack();
    expect(history.jumpToLatest()?.beatId, 'b2');
    expect(history.canForward, isFalse);
  });

  test('phase change on the same line does not add a step', () {
    final history = PlayHistory()
      ..record(_at('b1', 0))
      ..record(_at('b1', 0, phase: 'choices'));

    expect(history.entries, hasLength(1));
    expect(history.entries.single.phase, 'choices');
    expect(history.canForward, isFalse);
    expect(history.canBack, isFalse);
  });

  test('needsBridge reuses the last line entry', () {
    final history = PlayHistory()
      ..record(_at('b1', 0))
      ..record(_at('b1', 1))
      ..record(_at('b1', 1, phase: 'needsBridge'));

    expect(history.entries, hasLength(2));
    expect(history.stepBack()?.lineIndex, 0);
    expect(history.stepForward()?.phase, 'needsBridge');
  });

  test('clear resets the timeline', () {
    final history = PlayHistory()
      ..record(_at('b1', 0))
      ..clear();
    expect(history.isEmpty, isTrue);
    expect(history.cursor, -1);
    expect(history.canBack, isFalse);
    expect(history.canForward, isFalse);
  });
}
