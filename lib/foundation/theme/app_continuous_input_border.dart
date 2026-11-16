import 'package:flutter/material.dart';

/// Outline-style [InputBorder] using continuous-curvature corners.
class AppContinuousInputBorder extends InputBorder {
  const AppContinuousInputBorder({
    super.borderSide = const BorderSide(),
    this.borderRadius = BorderRadius.zero,
  });

  final BorderRadius borderRadius;

  RoundedSuperellipseBorder get _shape => RoundedSuperellipseBorder(
        side: borderSide,
        borderRadius: borderRadius,
      );

  @override
  bool get isOutline => true;

  @override
  AppContinuousInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
  }) {
    return AppContinuousInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _shape.getInnerPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _shape.getOuterPath(rect, textDirection: textDirection);
  }

  @override
  ShapeBorder scale(double t) {
    return AppContinuousInputBorder(
      borderSide: borderSide.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is AppContinuousInputBorder) {
      return AppContinuousInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is AppContinuousInputBorder) {
      return AppContinuousInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double gapPercentage = 0.0,
    double gapExtent = 0.0,
    double? gapStart,
    TextDirection? textDirection,
  }) {
    _shape.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is AppContinuousInputBorder &&
        other.borderSide == borderSide &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(borderSide, borderRadius);
}
