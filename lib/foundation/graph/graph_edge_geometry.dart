import 'dart:math' as math;
import 'dart:ui' show Offset, Path;

import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_card.dart';

/// Cubic bezier helpers for node-editor style wires (UE5-like).
abstract final class GraphEdgeGeometry {
  static const double portRowHeight = 28;
  static const double bodyPadV = 6;

  /// Card height that fits [count] vertically stacked output port rows.
  static double heightForOutputCount(
    int count, {
    bool headerSubtitle = false,
  }) {
    final n = math.max(1, count);
    final header = GraphNodeCard.headerHeight(hasSubtitle: headerSubtitle);
    return header + bodyPadV * 2 + n * portRowHeight;
  }

  /// Top of the port body (below header) within the node.
  static double bodyTop({bool headerSubtitle = false}) =>
      GraphNodeCard.headerHeight(hasSubtitle: headerSubtitle);

  /// Y of output / content row [index] within a node.
  static double outputPortLocalY({
    required int index,
    required int count,
    bool headerSubtitle = false,
  }) {
    final n = math.max(1, count);
    final i = index.clamp(0, n - 1);
    return bodyTop(headerSubtitle: headerSubtitle) +
        bodyPadV +
        i * portRowHeight +
        portRowHeight / 2;
  }

  /// Input port sits on the first content row (UE-style).
  static double inputPortLocalY({bool headerSubtitle = false}) =>
      outputPortLocalY(index: 0, count: 1, headerSubtitle: headerSubtitle);

  static int outputIndex(GraphNodeData node, String? portId) {
    final ports = node.outputs;
    if (ports.isEmpty) return 0;
    if (portId == null) return 0;
    final i = ports.indexWhere((p) => p.id == portId);
    return i < 0 ? 0 : i;
  }

  /// Output port center in canvas space.
  static Offset outputPort(GraphNodeData node, {String? portId}) {
    final count = math.max(1, node.outputs.length);
    final index = outputIndex(node, portId);
    final y = node.y +
        outputPortLocalY(
          index: index,
          count: count,
          headerSubtitle: node.hasHeaderSubtitle,
        );
    return Offset(node.x + node.resolvedWidth, y);
  }

  /// Input port: left edge, first content row.
  static Offset inputPort(GraphNodeData node) => Offset(
        node.x,
        node.y + inputPortLocalY(headerSubtitle: node.hasHeaderSubtitle),
      );

  /// Horizontal handle length — softens with distance, never too short.
  static double handleLength(Offset from, Offset to) {
    final dx = (to.dx - from.dx).abs();
    final dy = (to.dy - from.dy).abs();
    return (dx * 0.5).clamp(48.0, 180.0) + (dy * 0.08).clamp(0.0, 40.0);
  }

  static Offset controlOut(Offset from, Offset to) {
    final h = handleLength(from, to);
    return Offset(from.dx + h, from.dy);
  }

  static Offset controlIn(Offset from, Offset to) {
    final h = handleLength(from, to);
    return Offset(to.dx - h, to.dy);
  }

  static Path cubicPath(Offset from, Offset to) {
    final c1 = controlOut(from, to);
    final c2 = controlIn(from, to);
    return Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, to.dx, to.dy);
  }

  /// Point on cubic at [t] in 0..1.
  static Offset pointOnCubic(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final u = 1 - t;
    final uu = u * u;
    final tt = t * t;
    return p0 * (uu * u) +
        p1 * (3 * uu * t) +
        p2 * (3 * u * tt) +
        p3 * (tt * t);
  }

  /// Min distance from [point] to the cubic between [from] and [to].
  static double distanceToCubic(
    Offset point,
    Offset from,
    Offset to, {
    int samples = 28,
  }) {
    final c1 = controlOut(from, to);
    final c2 = controlIn(from, to);
    var best = double.infinity;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final d = (pointOnCubic(from, c1, c2, to, t) - point).distance;
      if (d < best) best = d;
    }
    return best;
  }

  /// Nearest edge id within [maxDistance], or null.
  static String? hitTestEdge({
    required Map<String, GraphNodeData> nodes,
    required List<GraphEdgeData> edges,
    required Offset point,
    double maxDistance = 12,
  }) {
    String? bestId;
    var best = maxDistance;
    for (final edge in edges) {
      final fromNode = nodes[edge.fromId];
      final toNode = nodes[edge.toId];
      if (fromNode == null || toNode == null) continue;
      final a = outputPort(fromNode, portId: edge.fromPortId ?? edge.id);
      final b = inputPort(toNode);
      final d = distanceToCubic(point, a, b);
      if (d <= best) {
        best = d;
        bestId = edge.id;
      }
    }
    return bestId;
  }
}
