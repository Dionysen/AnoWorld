import 'package:anoworld/domain/models/main_story.dart';

/// Folds AI-written [beats] into [main] (resume a slot, regenerate a segment).
///
/// Existing nodes are updated through [StoryNode.copyWith] so node-owned art
/// (station background, image prompt) and layout survive; rebuilding the node
/// from scratch silently dropped them and the stage lost its background.
MainStory mergeGeneratedBeats(MainStory main, List<Beat> beats) {
  var working = main;
  for (final beat in beats) {
    final node = working.nodeById(beat.nodeId);
    if (node == null) continue;
    final ids = node.beatIds.contains(beat.id)
        ? node.beatIds
        : [...node.beatIds, beat.id];
    working = MainStory(
      summary: working.summary,
      startNodeId: working.startNodeId,
      nodes: working.nodes
          .map((n) => n.id == node.id ? n.copyWith(beatIds: ids) : n)
          .toList(growable: false),
      edges: working.edges,
      beats: [
        ...working.beats.where((b) => b.id != beat.id),
        beat,
      ],
    );
  }
  return working;
}
