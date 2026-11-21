import 'dart:math' as math;

import 'package:anoworld/domain/models/main_story.dart';

/// Left-to-right layered layout from [MainStory.startNodeId] (BFS layers).
///
/// Editor-only: rewrites [StoryNode.layout]; does not change edges or runtime.
abstract final class MainGraphLayout {
  static const double defaultGapX = 72;
  static const double defaultGapY = 48;
  static const double defaultOriginX = 40;
  static const double defaultOriginY = 40;
  static const double fallbackWidth = 200;
  static const double fallbackHeight = 100;

  /// Arranges all nodes. Unreachable nodes (from start) sit in a column
  /// after the deepest reachable layer.
  static MainStory arrange(
    MainStory main, {
    Map<String, double>? widths,
    Map<String, double>? heights,
    double gapX = defaultGapX,
    double gapY = defaultGapY,
    double originX = defaultOriginX,
    double originY = defaultOriginY,
  }) {
    if (main.nodes.isEmpty) return main;

    final outs = <String, List<String>>{};
    for (final edge in main.edges) {
      outs.putIfAbsent(edge.from, () => <String>[]).add(edge.to);
    }

    final layerOf = <String, int>{};
    final queue = <String>[];
    if (main.nodeById(main.startNodeId) != null) {
      layerOf[main.startNodeId] = 0;
      queue.add(main.startNodeId);
    }
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      final depth = layerOf[id]!;
      for (final to in outs[id] ?? const <String>[]) {
        if (layerOf.containsKey(to)) continue;
        layerOf[to] = depth + 1;
        queue.add(to);
      }
    }

    final byLayer = <int, List<StoryNode>>{};
    final unreachable = <StoryNode>[];
    for (final node in main.nodes) {
      final layer = layerOf[node.id];
      if (layer == null) {
        unreachable.add(node);
        continue;
      }
      byLayer.putIfAbsent(layer, () => <StoryNode>[]).add(node);
    }

    int compareStable(StoryNode a, StoryNode b) {
      final ay = a.layout?.y ?? 0;
      final by = b.layout?.y ?? 0;
      final c = ay.compareTo(by);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    }

    for (final list in byLayer.values) {
      list.sort(compareStable);
    }
    unreachable.sort(compareStable);

    double widthOf(String id) => widths?[id] ?? fallbackWidth;
    double heightOf(String id) => heights?[id] ?? fallbackHeight;

    final layouts = <String, NodeLayout>{};
    var x = originX;
    final layers = byLayer.keys.toList()..sort();
    for (final layer in layers) {
      final column = byLayer[layer]!;
      var colW = 0.0;
      for (final node in column) {
        colW = math.max(colW, widthOf(node.id));
      }
      if (colW <= 0) colW = fallbackWidth;
      var y = originY;
      for (final node in column) {
        layouts[node.id] = NodeLayout(x: x, y: y);
        y += heightOf(node.id) + gapY;
      }
      x += colW + gapX;
    }

    if (unreachable.isNotEmpty) {
      var colW = 0.0;
      for (final node in unreachable) {
        colW = math.max(colW, widthOf(node.id));
      }
      if (colW <= 0) colW = fallbackWidth;
      var y = originY;
      for (final node in unreachable) {
        layouts[node.id] = NodeLayout(x: x, y: y);
        y += heightOf(node.id) + gapY;
      }
    }

    return main.copyWith(
      nodes: [
        for (final node in main.nodes)
          node.copyWith(layout: layouts[node.id] ?? node.layout),
      ],
    );
  }
}
