import 'dart:ui' show Offset;

import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:flutter/material.dart';

/// Draws smooth cubic wires (UE5-style) between node ports — no line arrows.
class GraphEdgePainter extends CustomPainter {
  GraphEdgePainter({
    required this.nodes,
    required this.edges,
    required this.strokeColor,
    required this.emphasisColor,
    required this.labelStyle,
    this.draftFrom,
    this.draftTo,
  });

  final Map<String, GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final Color strokeColor;
  final Color emphasisColor;
  final TextStyle labelStyle;
  final Offset? draftFrom;
  final Offset? draftTo;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final fromNode = nodes[edge.fromId];
      final toNode = nodes[edge.toId];
      if (fromNode == null || toNode == null) continue;
      paint.color = edge.emphasized ? emphasisColor : strokeColor;
      final a = GraphEdgeGeometry.outputPort(
        fromNode,
        portId: edge.fromPortId ?? edge.id,
      );
      final b = GraphEdgeGeometry.inputPort(toNode);
      canvas.drawPath(GraphEdgeGeometry.cubicPath(a, b), paint);
      final label = edge.label;
      if (label != null && label.isNotEmpty) {
        final c1 = GraphEdgeGeometry.controlOut(a, b);
        final c2 = GraphEdgeGeometry.controlIn(a, b);
        final mid = GraphEdgeGeometry.pointOnCubic(a, c1, c2, b, 0.5);
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: 120);
        tp.paint(
          canvas,
          Offset(mid.dx - tp.width / 2, mid.dy - tp.height - 6),
        );
      }
    }

    if (draftFrom != null && draftTo != null) {
      paint.color = emphasisColor.withValues(alpha: 0.7);
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
        oldDelegate.draftFrom != draftFrom ||
        oldDelegate.draftTo != draftTo ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.emphasisColor != emphasisColor;
  }
}
