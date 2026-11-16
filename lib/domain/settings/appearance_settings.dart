import 'package:anoworld/domain/models/json_map.dart';
import 'package:flutter/material.dart';

enum AppThemeModeSetting { system, light, dark }

extension AppThemeModeSettingX on AppThemeModeSetting {
  String get label => switch (this) {
        AppThemeModeSetting.system => '跟随系统',
        AppThemeModeSetting.light => '浅色',
        AppThemeModeSetting.dark => '深色',
      };

  ThemeMode get material => switch (this) {
        AppThemeModeSetting.system => ThemeMode.system,
        AppThemeModeSetting.light => ThemeMode.light,
        AppThemeModeSetting.dark => ThemeMode.dark,
      };

  static AppThemeModeSetting parse(String? raw) {
    return AppThemeModeSetting.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeModeSetting.dark,
    );
  }
}

/// Built-in color stories. Each preset supplies light + dark palettes.
enum AppThemePreset { midnight, slate, mist }

extension AppThemePresetX on AppThemePreset {
  String get label => switch (this) {
        AppThemePreset.midnight => '午夜',
        AppThemePreset.slate => '岩灰',
        AppThemePreset.mist => '薄雾',
      };

  String get blurb => switch (this) {
        AppThemePreset.midnight => '沉浸暗色，默认画布',
        AppThemePreset.slate => '冷灰强调，偏编辑器',
        AppThemePreset.mist => '浅色冷静，适合白天',
      };

  static AppThemePreset parse(String? raw) {
    return AppThemePreset.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => AppThemePreset.midnight,
    );
  }
}

enum AppTypeface { system, sans }

extension AppTypefaceX on AppTypeface {
  String get label => switch (this) {
        AppTypeface.system => '系统默认',
        AppTypeface.sans => '无衬线',
      };

  /// `null` keeps the platform default; otherwise Material-bundled Roboto.
  String? get fontFamily => switch (this) {
        AppTypeface.system => null,
        AppTypeface.sans => 'Roboto',
      };

  static AppTypeface parse(String? raw) {
    return AppTypeface.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => AppTypeface.system,
    );
  }
}

/// Slider ranges for appearance size controls (settings UI + clamp on load).
abstract final class AppearanceUiRange {
  /// Body text size in logical px.
  static const double fontSizeMin = 12;
  static const double fontSizeMax = 20;
  static const double fontSizeStep = 0.5;
  static const double fontSizeDefault = 15;

  static const double cornerRadiusMin = 0;
  static const double cornerRadiusMax = 24;
  static const double cornerRadiusStep = 1;
  static const double cornerRadiusDefault = 10;
}

class AppearanceSettings {
  const AppearanceSettings({
    this.mode = AppThemeModeSetting.dark,
    this.preset = AppThemePreset.midnight,
    this.typeface = AppTypeface.system,
    this.fontSize = AppearanceUiRange.fontSizeDefault,
    this.cornerRadius = AppearanceUiRange.cornerRadiusDefault,
  });

  final AppThemeModeSetting mode;
  final AppThemePreset preset;
  final AppTypeface typeface;

  /// Body text size in logical pixels (see [AppearanceUiRange]).
  final double fontSize;

  /// Continuous corner radius in logical pixels (see [AppearanceUiRange]).
  final double cornerRadius;

  AppearanceSettings copyWith({
    AppThemeModeSetting? mode,
    AppThemePreset? preset,
    AppTypeface? typeface,
    double? fontSize,
    double? cornerRadius,
  }) {
    return AppearanceSettings(
      mode: mode ?? this.mode,
      preset: preset ?? this.preset,
      typeface: typeface ?? this.typeface,
      fontSize: fontSize ?? this.fontSize,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'preset': preset.name,
        'typeface': typeface.name,
        'fontSize': fontSize,
        'cornerRadius': cornerRadius,
      };

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      mode: AppThemeModeSettingX.parse(json.optionalString('mode')),
      preset: AppThemePresetX.parse(json.optionalString('preset')),
      typeface: AppTypefaceX.parse(json.optionalString('typeface')),
      fontSize: _parseFontSize(json['fontSize'] ?? json['fontScale']),
      cornerRadius: _parseCornerRadius(json['cornerRadius']),
    );
  }

  static double _snapFontSize(double value) {
    final step = AppearanceUiRange.fontSizeStep;
    final snapped =
        (value / step).round() * step;
    return snapped.clamp(
      AppearanceUiRange.fontSizeMin,
      AppearanceUiRange.fontSizeMax,
    );
  }

  static double _parseFontSize(Object? raw) {
    final fromLegacy = switch (raw) {
      'small' => 13.5,
      'medium' => AppearanceUiRange.fontSizeDefault,
      'large' => 17.0,
      _ => null,
    };
    if (fromLegacy != null) return fromLegacy;

    if (raw is! num) return AppearanceUiRange.fontSizeDefault;
    final value = raw.toDouble();
    // Legacy multiplier (≈0.85–1.3) → body px.
    if (value > 0 && value < 3) {
      return _snapFontSize(value * AppearanceUiRange.fontSizeDefault);
    }
    return _snapFontSize(value);
  }

  static double _parseCornerRadius(Object? raw) {
    final fromLegacy = switch (raw) {
      'compact' => 6.0,
      'medium' => 10.0,
      'soft' => 16.0,
      _ => null,
    };
    final value = fromLegacy ??
        (raw is num
            ? raw.toDouble()
            : AppearanceUiRange.cornerRadiusDefault);
    return value.clamp(
      AppearanceUiRange.cornerRadiusMin,
      AppearanceUiRange.cornerRadiusMax,
    );
  }
}
