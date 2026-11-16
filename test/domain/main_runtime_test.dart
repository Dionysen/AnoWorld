import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/main_runtime.dart';
import 'package:anoworld/domain/runtime/play_pointer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  test('starts on first beat first line', () {
    final runtime = MainRuntime(sample.main);
    expect(runtime.pointer.nodeId, 'n1');
    expect(runtime.pointer.beatId, 'b1');
    expect(runtime.pointer.phase, PlayPhase.lines);
    expect(runtime.currentLine?.text, '该走了。');
    expect(runtime.resolvedBackgroundAssetId, 'bg_gate');
  });

  test('advances across default edge into inn choices', () {
    final runtime = MainRuntime(sample.main);
    runtime.advance(); // finish b1 → default edge → b2
    expect(runtime.pointer.nodeId, 'n2');
    expect(runtime.pointer.beatId, 'b2');
    expect(runtime.currentLine?.text, '留宿？');

    runtime.advance(); // lines done → choices
    expect(runtime.pointer.phase, PlayPhase.choices);
    expect(runtime.visibleChoices.map((c) => c.id), <String>['ch1', 'ch2']);
  });

  test('choice end finishes the run', () {
    final runtime = MainRuntime(sample.main);
    runtime.advance();
    runtime.advance();
    runtime.choose('ch1');
    expect(runtime.pointer.isEnded, isTrue);
  });

  test('choice to beat re-enters the same beat', () {
    final runtime = MainRuntime(sample.main);
    runtime.advance();
    runtime.advance();
    runtime.choose('ch2');
    expect(runtime.pointer.beatId, 'b2');
    expect(runtime.pointer.phase, PlayPhase.lines);
    expect(runtime.currentLine?.text, '留宿？');
  });

  test('restore save pointer', () {
    final runtime = MainRuntime(
      sample.main,
      save: const MainSavePointer(nodeId: 'n2', beatId: 'b2'),
    );
    expect(runtime.pointer.nodeId, 'n2');
    expect(runtime.currentLine?.text, '留宿？');
  });

  test('background inherits within node only', () {
    final main = sample.main.copyWith(
      beats: [
        sample.main.beats[0],
        Beat(
          id: 'b2',
          nodeId: 'n2',
          scene: const Scene(locationText: '客栈'),
          appearances: sample.main.beats[1].appearances,
          lines: sample.main.beats[1].lines,
          choices: sample.main.beats[1].choices,
        ),
      ],
    );
    // Put two beats on n1: first with bg, second without.
    final patched = main.copyWith(
      nodes: [
        const StoryNode(
          id: 'n1',
          title: '城门',
          beatIds: ['b1', 'b1b'],
        ),
        main.nodes[1],
      ],
      beats: [
        main.beats[0],
        Beat(
          id: 'b1b',
          nodeId: 'n1',
          scene: const Scene(locationText: '城门外'),
          appearances: const [],
          lines: const [
            DialogueLine(id: 'l1b', text: '雨更大了。', kind: DialogueKind.narration),
          ],
          choices: const [],
        ),
        main.beats[1],
      ],
      edges: main.edges,
    );
    final runtime = MainRuntime(
      patched,
      save: const MainSavePointer(nodeId: 'n1', beatId: 'b1b'),
    );
    expect(runtime.resolvedBackgroundAssetId, 'bg_gate');
  });
}
