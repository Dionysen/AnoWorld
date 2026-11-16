import 'dart:ui' show Offset;

import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:flutter/material.dart';

/// Draws straight edges with optional labels between node centers.
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
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final from = nodes[edge.fromId];
      final to = nodes[edge.toId];
      if (from == null || to == null) continue;
      paint.color = edge.emphasized ? emphasisColor : strokeColor;
      final a = from.center;
      final b = to.center;
      canvas.drawLine(a, b, paint);
      _drawArrow(canvas, a, b, paint.color);
      final label = edge.label;
      if (label != null && label.isNotEmpty) {
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 10);
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: 120);
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
      }
    }

    if (draftFrom != null && draftTo != null) {
      paint.color = emphasisColor.withValues(alpha: 0.7);
      canvas.drawLine(draftFrom!, draftTo!, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset a, Offset b, Color color) {
    final direction = (b - a);
    final distance = direction.distance;
    if (distance < 1) return;
    final unit = direction / distance;
    final tip = b - unit * 28;
    final ortho = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(tip.dx + unit.dx * 8, tip.dy + unit.dy * 8)
      ..lineTo(tip.dx - ortho.dx * 5, tip.dy - ortho.dy * 5)
      ..lineTo(tip.dx + ortho.dx * 5, tip.dy + ortho.dy * 5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
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
