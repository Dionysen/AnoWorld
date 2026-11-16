import 'dart:ui' show Offset;

import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:flutter/material.dart';

/// Draws smooth cubic wires (UE5-style) between node ports — no line labels.
class GraphEdgePainter extends CustomPainter {
  GraphEdgePainter({
    required this.nodes,
    required this.edges,
    required this.strokeColor,
    required this.emphasisColor,
    this.selectedEdgeId,
    this.draftFrom,
    this.draftTo,
  });

  final Map<String, GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final Color strokeColor;
  final Color emphasisColor;
  final String? selectedEdgeId;
  final Offset? draftFrom;
  final Offset? draftTo;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final fromNode = nodes[edge.fromId];
      final toNode = nodes[edge.toId];
      if (fromNode == null || toNode == null) continue;
      final selected = edge.id == selectedEdgeId;
      paint
        ..color = selected ? emphasisColor : strokeColor
        ..strokeWidth = selected ? 3.5 : 2.25;
      final a = GraphEdgeGeometry.outputPort(
        fromNode,
        portId: edge.fromPortId ?? edge.id,
      );
      final b = GraphEdgeGeometry.inputPort(toNode);
      canvas.drawPath(GraphEdgeGeometry.cubicPath(a, b), paint);
    }

    if (draftFrom != null && draftTo != null) {
      paint
        ..color = emphasisColor.withValues(alpha: 0.7)
        ..strokeWidth = 2.25;
      canvas.drawPath(
        GraphEdgeGeometry.cubicPath(draftFrom!, draftTo!),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GraphEdgePainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.selectedEdgeId != selectedEdgeId ||
        oldDelegate.draftFrom != draftFrom ||
        oldDelegate.draftTo != draftTo ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.emphasisColor != emphasisColor;
  }
}
