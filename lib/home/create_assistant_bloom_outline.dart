import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Metrics for the assistant bloom silhouette.
@immutable
class CreateAssistantBloomMetrics {
  const CreateAssistantBloomMetrics({
    required this.width,
    required this.panelHeight,
    required this.neckGap,
    required this.anchor,
    required this.cornerRadius,
  });

  final double width;
  final double panelHeight;
  final double neckGap;
  final double anchor;
  final double cornerRadius;

  double get totalHeight => panelHeight + neckGap + anchor;

  Offset get buttonCenter =>
      Offset(width - anchor / 2, panelHeight + neckGap + anchor / 2);

  double get buttonRadius => anchor / 2;
}

/// One closed contour: panel, surface-tension waist, and anchor circle.
///
/// Fill and stroke share this path. Control points stay tangent to the panel
/// edge and to the circle, so the waist can tighten without a seam or a kink.
class CreateAssistantBloomOutline {
  CreateAssistantBloomOutline._();

  static const double designAnchor = 56;
  static const double designNeckGap = 12;

  /// [neckStrength] 0…1. 0 is a wide fused join; 1 is the tense waist.
  static Path build(CreateAssistantBloomMetrics m, {double neckStrength = 1}) {
    final a = m.anchor;
    final w = m.width;
    final h = m.panelHeight;
    final g = math.max(0.0, m.neckGap);
    final br = m.buttonRadius;
    final cx = m.buttonCenter.dx;
    final cy = m.buttonCenter.dy;
    final strength = neckStrength.clamp(0.0, 1.0);

    final collapsed = h < 1.0 && g < 0.5;
    if (collapsed || w < a * 0.5 || h < 0) {
      return Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: br));
    }

    final scale = a / designAnchor;
    // Smoothstep so the waist eases in and settles instead of moving linearly.
    final tense = strength * strength * (3 - 2 * strength);

    final theta = _lerp(1.32, 0.80, tense);
    final chord = br * math.sin(theta);
    var pinchHalf = _lerp(br * 0.92, 13.0 * scale, tense);
    pinchHalf = math.min(pinchHalf, chord * 0.96);
    var topHalf = _lerp(br * 1.02, br * 0.80, tense);

    final maxR = math.min(w, h) / 2;
    var r = math.min(m.cornerRadius, maxR);
    final landing = 8.0 * scale;
    final fillet = 12.0 * scale;
    final needed = pinchHalf + fillet + landing;
    final rFit = cx - needed;
    if (rFit >= 4) {
      r = math.min(r, rFit);
    } else {
      r = math.min(r, math.max(4.0, maxR * 0.5));
    }
    r = r.clamp(0.0, maxR);

    final neckRoom = math.max(6.0, cx - r - landing);
    pinchHalf = math.min(pinchHalf, neckRoom * 0.72);
    topHalf = math.min(neckRoom, math.max(topHalf, pinchHalf + fillet));
    pinchHalf = math.min(pinchHalf, topHalf * 0.86);
    pinchHalf = math.max(3.0, pinchHalf);

    final rightIndent = math.max(0.0, w - (cx + pinchHalf));
    final inset = math.max(_lerp(10.0, 22.0 * scale, tense), rightIndent * 2.4);
    final neckStartY = math.max(r, h - inset);
    // The waist sits in the span from the panel underside to where the
    // curves meet the circle, not in the raw gap (that span is tiny at
    // the start of the bloom and a vertical tangent there hairpins).
    final shoulderDrop = br * (1 - math.cos(theta));
    final pinchY = h + (g + shoulderDrop) * _lerp(0.40, 0.56, tense);
    final attachX = math.max(r, cx - topHalf);

    final startAngle = -math.pi / 2 + theta;
    final sweep = math.pi * 2 - theta * 2;
    final circleR = _circlePoint(cx, cy, br, startAngle);
    final endAngle = startAngle + sweep;
    final circleL = _circlePoint(cx, cy, br, endAngle);
    final leaveL = _arcTangent(endAngle);

    final path = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(math.max(r, w - r), 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, neckStartY);

    _cubic(
      path,
      Offset(w, neckStartY),
      const Offset(0, 1),
      Offset(cx + pinchHalf, pinchY),
      const Offset(0, 1),
      0.58,
    );
    _cubic(
      path,
      Offset(cx + pinchHalf, pinchY),
      const Offset(0, 1),
      circleR,
      _arcTangent(startAngle),
      0.55,
    );
    path.arcTo(
      Rect.fromCircle(center: Offset(cx, cy), radius: br),
      startAngle,
      sweep,
      false,
    );
    _cubic(
      path,
      circleL,
      leaveL,
      Offset(cx - pinchHalf, pinchY),
      const Offset(0, -1),
      0.55,
    );
    _cubic(
      path,
      Offset(cx - pinchHalf, pinchY),
      const Offset(0, -1),
      Offset(attachX, h),
      const Offset(-1, 0),
      0.58,
    );

    if (attachX > r + 0.5) {
      path.lineTo(r, h);
    }
    path
      ..quadraticBezierTo(0, h, 0, math.max(r, h - r))
      ..close();
    return path;
  }

  /// Open-state reference path (design lock-in for tests).
  static Path openReference({double width = 420, double panelHeight = 520}) {
    return build(
      CreateAssistantBloomMetrics(
        width: width,
        panelHeight: panelHeight,
        neckGap: designNeckGap,
        anchor: designAnchor,
        cornerRadius: 16,
      ),
    );
  }
}

Offset _circlePoint(double cx, double cy, double radius, double angle) {
  return Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle));
}

/// Clockwise tangent of [Path.arcTo] at [angle] (0 is +x, y grows down).
Offset _arcTangent(double angle) {
  return Offset(-math.sin(angle), math.cos(angle));
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

void _cubic(
  Path path,
  Offset from,
  Offset fromDir,
  Offset to,
  Offset toDir,
  double tension,
) {
  final delta = to - from;
  final dist = delta.distance;
  if (dist < 0.4) {
    path.lineTo(to.dx, to.dy);
    return;
  }
  final d0 = _unit(fromDir);
  final d1 = _unit(toDir);
  final along0 = delta.dx * d0.dx + delta.dy * d0.dy;
  final along1 = delta.dx * d1.dx + delta.dy * d1.dy;
  // Keep each handle inside the segment so the two controls cannot cross
  // and fold the waist back on itself.
  final h0 = _handle(dist, tension, along0);
  final h1 = _handle(dist, tension, along1);
  final c1 = from + d0 * h0;
  final c2 = to - d1 * h1;
  path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, to.dx, to.dy);
}

double _handle(double dist, double tension, double along) {
  final preferred = dist * tension;
  if (along <= 0.5) return math.min(preferred, dist * 0.18);
  return math.min(preferred, along * 0.55);
}

Offset _unit(Offset v) {
  final d = v.distance;
  if (d < 1e-6) return const Offset(0, 1);
  return v / d;
}
