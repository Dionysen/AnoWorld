import 'package:anoworld/foundation/graph/graph_grid_lod.dart';
import 'package:flutter/material.dart';

/// Screen-space grid aligned to the [InteractiveViewer] scene matrix.
///
/// Line spacing follows [GraphGridLod] so zoom keeps a readable density.
class GraphGridPainter extends CustomPainter {
  GraphGridPainter({
    required this.transform,
    required this.color,
    this.minorOpacity = 0.22,
    this.majorOpacity = 0.4,
  });

  final Matrix4 transform;
  final Color color;
  final double minorOpacity;
  final double majorOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    Matrix4 inverse;
    try {
      inverse = Matrix4.inverted(transform);
    } catch (_) {
      return;
    }

    final scale = transform.getMaxScaleOnAxis().clamp(0.001, 100.0);
    final step = GraphGridLod.stepForScale(scale);
    if (step <= 0) return;

    final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
    final topRight =
        MatrixUtils.transformPoint(inverse, Offset(size.width, 0));
    final bottomLeft =
        MatrixUtils.transformPoint(inverse, Offset(0, size.height));
    final bottomRight = MatrixUtils.transformPoint(
      inverse,
      Offset(size.width, size.height),
    );

    final minX = _min4(topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx);
    final maxX = _max4(topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx);
    final minY = _min4(topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy);
    final maxY = _max4(topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy);

    final startX = (minX / step).floor() * step;
    final startY = (minY / step).floor() * step;
    final startIndexX = (startX / step).round();
    final startIndexY = (startY / step).round();

    final minor = Paint()
      ..color = color.withValues(alpha: minorOpacity)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = color.withValues(alpha: majorOpacity)
      ..strokeWidth = 1;

    var index = startIndexX;
    for (var x = startX; x <= maxX + step * 0.5; x += step, index++) {
      final screenX = MatrixUtils.transformPoint(
        transform,
        Offset(x, 0),
      ).dx;
      final paint =
          GraphGridLod.isMajorIndex(index) ? major : minor;
      canvas.drawLine(
        Offset(screenX, 0),
        Offset(screenX, size.height),
        paint,
      );
    }

    index = startIndexY;
    for (var y = startY; y <= maxY + step * 0.5; y += step, index++) {
      final screenY = MatrixUtils.transformPoint(
        transform,
        Offset(0, y),
      ).dy;
      final paint =
          GraphGridLod.isMajorIndex(index) ? major : minor;
      canvas.drawLine(
        Offset(0, screenY),
        Offset(size.width, screenY),
        paint,
      );
    }
  }

  static double _min4(double a, double b, double c, double d) =>
      a < b
          ? (a < c ? (a < d ? a : d) : (c < d ? c : d))
          : (b < c ? (b < d ? b : d) : (c < d ? c : d));

  static double _max4(double a, double b, double c, double d) =>
      a > b
          ? (a > c ? (a > d ? a : d) : (c > d ? c : d))
          : (b > c ? (b > d ? b : d) : (c > d ? c : d));

  @override
  bool shouldRepaint(covariant GraphGridPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.color != color ||
        oldDelegate.minorOpacity != minorOpacity ||
        oldDelegate.majorOpacity != majorOpacity;
  }
}
