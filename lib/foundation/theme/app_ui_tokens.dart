import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_shapes.dart';
import 'app_theme.dart';

/// Runtime UI metrics carried on [ThemeData] (radius, field padding, type size).
@immutable
class AppUiTokens extends ThemeExtension<AppUiTokens> {
  const AppUiTokens({
    required this.radius,
    required this.fontSize,
    required this.fontFamily,
    required this.fieldPadding,
    this.spaceInline = AppTheme.spaceInline,
  });

  static const fallback = AppUiTokens(
    radius: 10,
    fontSize: 15,
    fontFamily: null,
    fieldPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    spaceInline: AppTheme.spaceInline,
  );

  /// Continuous-corner radius in logical pixels.
  final double radius;

  /// Body text size in logical pixels (px).
  final double fontSize;

  final String? fontFamily;
  final EdgeInsets fieldPadding;

  /// Gap between adjacent controls in one row.
  final double spaceInline;

  static AppUiTokens of(BuildContext context) {
    return Theme.of(context).extension<AppUiTokens>() ?? fallback;
  }

  RoundedSuperellipseBorder shape({BorderSide side = BorderSide.none}) {
    return AppShapes.continuous(radius: radius, side: side);
  }

  @override
  AppUiTokens copyWith({
    double? radius,
    double? fontSize,
    String? fontFamily,
    EdgeInsets? fieldPadding,
    double? spaceInline,
    bool clearFontFamily = false,
  }) {
    return AppUiTokens(
      radius: radius ?? this.radius,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
      fieldPadding: fieldPadding ?? this.fieldPadding,
      spaceInline: spaceInline ?? this.spaceInline,
    );
  }

  @override
  AppUiTokens lerp(ThemeExtension<AppUiTokens>? other, double t) {
    if (other is! AppUiTokens) return this;
    return AppUiTokens(
      radius: lerpDouble(radius, other.radius, t) ?? radius,
      fontSize: lerpDouble(fontSize, other.fontSize, t) ?? fontSize,
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      fieldPadding: EdgeInsets.lerp(fieldPadding, other.fieldPadding, t) ??
          fieldPadding,
      spaceInline: lerpDouble(spaceInline, other.spaceInline, t) ?? spaceInline,
    );
  }
}
