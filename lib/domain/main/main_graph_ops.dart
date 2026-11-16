import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';

/// Immutable updates for Main nodes / edges (editor + generators).
class MainGraphOps {
  const MainGraphOps();

  MainStory upsertNode(MainStory main, StoryNode node) {
    final nodes = [...main.nodes];
    final index = nodes.indexWhere((n) => n.id == node.id);
    if (index < 0) {
      nodes.add(node);
    } else {
      nodes[index] = node;
    }
    return main.copyWith(nodes: List<StoryNode>.unmodifiable(nodes));
  }

  MainStory moveNode(MainStory main, String nodeId, NodeLayout layout) {
    final node = main.nodeById(nodeId);
    if (node == null) return main;
    return upsertNode(
      main,
      StoryNode(
        id: node.id,
        title: node.title,
        synopsis: node.synopsis,
        beatIds: node.beatIds,
        layout: layout,
        tags: node.tags,
      ),
    );
  }

  MainStory updateNodeMeta(
    MainStory main, {
    required String nodeId,
    String? title,
    String? synopsis,
    StoryNodeKind? kind,
  }) {
    final node = main.nodeById(nodeId);
    if (node == null) return main;
    return upsertNode(
      main,
      StoryNode(
        id: node.id,
        title: title ?? node.title,
        synopsis: synopsis ?? node.synopsis,
        beatIds: node.beatIds,
        layout: node.layout,
        tags: kind == null ? node.tags : StoryNodeKind.apply(node.tags, kind),
      ),
    );
  }

  MainStory setNodeKind(MainStory main, String nodeId, StoryNodeKind kind) {
    return updateNodeMeta(main, nodeId: nodeId, kind: kind);
  }

  /// Copies title / synopsis / tags into a new station offset on the canvas.
  /// Does not copy beats or edges.
  MainStory duplicateNode(MainStory main, String nodeId) {
    final node = main.nodeById(nodeId);
    if (node == null) return main;
    final id = newNodeId(main);
    final x = (node.layout?.x ?? 40) + 48;
    final y = (node.layout?.y ?? 40) + 48;
    return upsertNode(
      main,
      StoryNode(
        id: id,
        title: node.title,
        synopsis: node.synopsis,
        beatIds: const [],
        layout: NodeLayout(x: x, y: y),
        tags: node.tags,
      ),
    );
  }

  /// Removes the node, its beats, and all incident edges.
  MainStory removeNode(MainStory main, String nodeId) {
    if (!main.nodes.any((n) => n.id == nodeId)) return main;
    final removedBeatIds = <String>{
      for (final n in main.nodes)
        if (n.id == nodeId) ...n.beatIds,
    };
    final nodes =
        main.nodes.where((n) => n.id != nodeId).toList(growable: false);
    final edges = main.edges
        .where((e) => e.from != nodeId && e.to != nodeId)
        .toList(growable: false);
    final beats = main.beats
        .where((b) => !removedBeatIds.contains(b.id) && b.nodeId != nodeId)
        .toList(growable: false);
    var start = main.startNodeId;
    if (start == nodeId) {
      start = nodes.isEmpty ? '' : nodes.first.id;
    }
    return MainStory(
      summary: main.summary,
      startNodeId: start,
      nodes: nodes,
      edges: edges,
      beats: beats,
    );
  }

  MainStory addEdge(MainStory main, StoryEdge edge) {
    if (main.edges.any((e) => e.id == edge.id)) {
      return upsertEdge(main, edge);
    }
    return main.copyWith(
      edges: List<StoryEdge>.unmodifiable([...main.edges, edge]),
    );
  }

  MainStory upsertEdge(MainStory main, StoryEdge edge) {
    final edges = [...main.edges];
    final index = edges.indexWhere((e) => e.id == edge.id);
    if (index < 0) {
      edges.add(edge);
    } else {
      edges[index] = edge;
    }
    return main.copyWith(edges: List<StoryEdge>.unmodifiable(edges));
  }

  MainStory removeEdge(MainStory main, String edgeId) {
    return main.copyWith(
      edges: main.edges
          .where((e) => e.id != edgeId)
          .toList(growable: false),
    );
  }

  MainStory setStartNode(MainStory main, String nodeId) {
    if (main.nodeById(nodeId) == null) return main;
    return main.copyWith(startNodeId: nodeId);
  }

  List<StoryEdge> outgoing(MainStory main, String nodeId) => main.edges
      .where((e) => e.from == nodeId)
      .toList(growable: false);

  List<StoryEdge> incoming(MainStory main, String nodeId) => main.edges
      .where((e) => e.to == nodeId)
      .toList(growable: false);

  static String newNodeId(MainStory main) {
    var n = main.nodes.length + 1;
    while (main.nodeById('n_$n') != null) {
      n++;
    }
    return 'n_$n';
  }

  static String newEdgeId(MainStory main) {
    var n = main.edges.length + 1;
    while (main.edges.any((e) => e.id == 'e_$n')) {
      n++;
    }
    return 'e_$n';
  }
}
