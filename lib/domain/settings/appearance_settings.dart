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

class AppearanceSettings {
  const AppearanceSettings({
    this.mode = AppThemeModeSetting.dark,
    this.preset = AppThemePreset.midnight,
  });

  final AppThemeModeSetting mode;
  final AppThemePreset preset;

  AppearanceSettings copyWith({
    AppThemeModeSetting? mode,
    AppThemePreset? preset,
  }) {
    return AppearanceSettings(
      mode: mode ?? this.mode,
      preset: preset ?? this.preset,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'preset': preset.name,
      };

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      mode: AppThemeModeSettingX.parse(json.optionalString('mode')),
      preset: AppThemePresetX.parse(json.optionalString('preset')),
    );
  }
}
