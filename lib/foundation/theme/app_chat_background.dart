import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chat backdrop kinds (aligned with NativeTavern `BackgroundType`).
enum AppChatBackgroundKind {
  none,
  color,
  gradient,
}

/// Chat-only backdrop. Portable — no product types.
class AppChatBackground {
  const AppChatBackground({
    this.kind = AppChatBackgroundKind.none,
    this.colorHex,
    this.gradientColors,
    this.gradientAngle = 180,
  });

  final AppChatBackgroundKind kind;

  /// `#RRGGBB` solid fill when [kind] is [AppChatBackgroundKind.color].
  final String? colorHex;

  /// `#RRGGBB` stops when [kind] is [AppChatBackgroundKind.gradient].
  final List<String>? gradientColors;

  /// Linear gradient angle: 0 = top, clockwise degrees.
  final double gradientAngle;

  static const AppChatBackground none = AppChatBackground();

  factory AppChatBackground.solid(String hex) => AppChatBackground(
        kind: AppChatBackgroundKind.color,
        colorHex: hex,
      );

  factory AppChatBackground.linearGradient(
    List<String> colors, {
    double angle = 180,
  }) =>
      AppChatBackground(
        kind: AppChatBackgroundKind.gradient,
        gradientColors: List<String>.unmodifiable(colors),
        gradientAngle: angle,
      );

  AppChatBackground copyWith({
    AppChatBackgroundKind? kind,
    String? colorHex,
    List<String>? gradientColors,
    double? gradientAngle,
  }) {
    return AppChatBackground(
      kind: kind ?? this.kind,
      colorHex: colorHex ?? this.colorHex,
      gradientColors: gradientColors ?? this.gradientColors,
      gradientAngle: gradientAngle ?? this.gradientAngle,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'colorHex': colorHex,
        'gradientColors': gradientColors,
        'gradientAngle': gradientAngle,
      };

  factory AppChatBackground.fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    final kindName = json['kind'];
    final kind = AppChatBackgroundKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => AppChatBackgroundKind.none,
    );
    final colorsRaw = json['gradientColors'];
    final colors = colorsRaw is List
        ? colorsRaw.whereType<String>().toList(growable: false)
        : null;
    final angle = (json['gradientAngle'] as num?)?.toDouble() ?? 180;
    final hex = json['colorHex'] is String ? json['colorHex'] as String : null;
    return AppChatBackground(
      kind: kind,
      colorHex: hex,
      gradientColors: colors,
      gradientAngle: angle,
    );
  }

  bool matches(AppChatBackground other) {
    if (kind != other.kind) return false;
    switch (kind) {
      case AppChatBackgroundKind.none:
        return true;
      case AppChatBackgroundKind.color:
        return _norm(colorHex) == _norm(other.colorHex);
      case AppChatBackgroundKind.gradient:
        return _normList(gradientColors) == _normList(other.gradientColors) &&
            gradientAngle == other.gradientAngle;
    }
  }

  static String? _norm(String? hex) => hex?.replaceAll('#', '').toUpperCase();

  static String _normList(List<String>? colors) =>
      (colors ?? const <String>[]).map(_norm).join(',');

  static Color parseHex(String? hex, {Color fallback = Colors.transparent}) {
    if (hex == null || hex.isEmpty) return fallback;
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return fallback;
    return Color(int.parse(value, radix: 16));
  }

  static Alignment angleToAlignment(double angle) {
    final rad = angle * math.pi / 180.0;
    return Alignment(math.sin(rad), -math.cos(rad));
  }

  Gradient? toGradient() {
    if (kind != AppChatBackgroundKind.gradient) return null;
    final colors = (gradientColors ?? const <String>['#000000', '#333333'])
        .map(parseHex)
        .toList(growable: false);
    return LinearGradient(
      begin: angleToAlignment(gradientAngle),
      end: angleToAlignment(gradientAngle + 180),
      colors: colors,
    );
  }

  /// Curated presets (NT `BackgroundPresets`, trimmed for MVP).
  static const List<AppChatBackground> gradientPresets = [
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#1F1F1F', '#313131'],
      gradientAngle: 180,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#10131B', '#2A3348'],
      gradientAngle: 180,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#1A1025', '#3D2A55'],
      gradientAngle: 160,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#0F1A18', '#1F3A34'],
      gradientAngle: 180,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#1A1210', '#4A2E24'],
      gradientAngle: 145,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#F1F3F6', '#FFFFFF'],
      gradientAngle: 180,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#F4F0E9', '#FCFAF7'],
      gradientAngle: 180,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#E5F2EC', '#FBFDFC'],
      gradientAngle: 180,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#F0E6FB', '#FCF9FF'],
      gradientAngle: 180,
    ),
    AppChatBackground(
      kind: AppChatBackgroundKind.gradient,
      gradientColors: ['#DBEAFE', '#EFF6FF'],
      gradientAngle: 180,
    ),
  ];

  static const List<AppChatBackground> solidPresets = [
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#1F1F1F'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#10131B'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#2A1F3D'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#1B2D2A'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#3A241C'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#FFFFFF'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#F4F0E9'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#E5F2EC'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#F0E6FB'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#DBEAFE'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#FEE2E2'),
    AppChatBackground(kind: AppChatBackgroundKind.color, colorHex: '#FFF7ED'),
  ];

  @override
  bool operator ==(Object other) {
    return other is AppChatBackground && matches(other);
  }

  @override
  int get hashCode => Object.hash(
        kind,
        _norm(colorHex),
        _normList(gradientColors),
        gradientAngle,
      );
}
