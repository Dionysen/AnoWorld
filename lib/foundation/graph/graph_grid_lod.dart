import 'dart:math' as math;

/// Picks a scene-space grid step so on-screen spacing stays comfortable.
abstract final class GraphGridLod {
  /// Preferred minor-line spacing in viewport pixels.
  static const double targetScreenPx = 32;

  /// Every N-th minor line is drawn as a major line.
  static const int majorEvery = 5;

  /// Scene-space distance between minor lines at the given camera [scale].
  static double stepForScale(
    double scale, {
    double targetPx = targetScreenPx,
  }) {
    final s = scale.clamp(0.001, 100.0);
    return _nice(targetPx / s);
  }

  /// True when this minor index should use the major stroke.
  static bool isMajorIndex(int index, {int every = majorEvery}) {
    if (every <= 1) return true;
    return index % every == 0;
  }

  /// 1–2–5 × 10^n series (stable under zoom).
  static double _nice(double raw) {
    if (raw <= 0 || raw.isNaN || raw.isInfinite) {
      return targetScreenPx;
    }
    final exp = (math.log(raw) / math.ln10).floor();
    final mag = math.pow(10.0, exp).toDouble();
    final n = raw / mag;
    final nice = n < 1.5
        ? 1
        : n < 3.5
            ? 2
            : n < 7.5
                ? 5
                : 10;
    return nice * mag;
  }
}
