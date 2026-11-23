import 'package:anoworld/domain/main/merge_generated_beats.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const node = StoryNode(
    id: 'n1',
    title: '城门',
    synopsis: '离开',
    beatIds: ['b0'],
    backgroundAssetId: 'asset_bg',
    imagePrompt: 'rainy gate',
    tags: ['scene'],
    layout: NodeLayout(x: 10, y: 20),
  );
  const main = MainStory(
    summary: '短主线',
    startNodeId: 'n1',
    nodes: [node],
    edges: [],
    beats: [
      Beat(
        id: 'b0',
        nodeId: 'n1',
        scene: Scene(locationText: '城门'),
        appearances: [],
        lines: [],
        choices: [],
      ),
    ],
  );
  const beat = Beat(
    id: 'b1',
    nodeId: 'n1',
    scene: Scene(locationText: '城门'),
    appearances: [],
    lines: [],
    choices: [],
  );

  test('keeps station art when folding generated beats back in', () {
    final merged = mergeGeneratedBeats(main, [beat]);

    final mergedNode = merged.nodeById('n1')!;
    expect(mergedNode.beatIds, ['b0', 'b1']);
    // Station background / prompt / layout must survive a resume.
    expect(mergedNode.backgroundAssetId, 'asset_bg');
    expect(mergedNode.imagePrompt, 'rainy gate');
    expect(mergedNode.tags, ['scene']);
    expect(mergedNode.layout?.x, 10);
    expect(mergedNode.title, '城门');
    expect(merged.beats.map((b) => b.id), containsAll(['b0', 'b1']));
  });

  test('replaces a beat with the same id instead of duplicating it', () {
    const rewritten = Beat(
      id: 'b0',
      nodeId: 'n1',
      scene: Scene(locationText: '城门改'),
      appearances: [],
      lines: [],
      choices: [],
    );

    final merged = mergeGeneratedBeats(main, [rewritten]);

    expect(merged.beats.length, 1);
    expect(merged.nodeById('n1')!.beatIds, ['b0']);
    expect(merged.beats.single.scene.locationText, '城门改');
  });

  test('ignores beats whose station is gone', () {
    const orphan = Beat(
      id: 'b9',
      nodeId: 'n_missing',
      scene: Scene(),
      appearances: [],
      lines: [],
      choices: [],
    );

    final merged = mergeGeneratedBeats(main, [orphan]);

    expect(merged.beats.length, 1);
    expect(merged.nodeById('n1')!.beatIds, ['b0']);
  });
}
