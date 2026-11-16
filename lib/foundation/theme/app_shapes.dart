import 'package:flutter/material.dart';

/// Continuous-curvature (superellipse) shapes for chrome and controls.
abstract final class AppShapes {
  static RoundedSuperellipseBorder continuous({
    required double radius,
    BorderSide side = BorderSide.none,
  }) {
    return RoundedSuperellipseBorder(
      side: side,
      borderRadius: BorderRadius.circular(radius.clamp(0, double.infinity)),
    );
  }

  static ShapeBorderClipper clipper({
    required double radius,
    TextDirection? textDirection,
  }) {
    return ShapeBorderClipper(
      shape: continuous(radius: radius),
      textDirection: textDirection,
    );
  }
}
