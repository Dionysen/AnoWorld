import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/theme/theme_color_pack.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
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
      orElse: () => AppThemeModeSetting.system,
    );
  }
}

/// Slider ranges for appearance size controls (settings UI + clamp on load).
abstract final class AppearanceUiRange {
  static const double fontSizeMin = 12;
  static const double fontSizeMax = 20;
  static const double fontSizeStep = 0.5;
  static const double fontSizeDefault = 15;

  static const double cornerRadiusMin = 0;
  static const double cornerRadiusMax = 24;
  static const double cornerRadiusStep = 1;
  static const double cornerRadiusDefault = 10;
}

/// Persisted appearance: mode, light/dark token slots, custom packs, chrome.
class AppearanceSettings {
  AppearanceSettings({
    this.mode = AppThemeModeSetting.system,
    ThemeTokens? lightTokens,
    ThemeTokens? darkTokens,
    String? lightPackId,
    String? darkPackId,
    this.customPacks = const [],
    this.fontFamily,
    this.fontPath,
    this.fontSize = AppearanceUiRange.fontSizeDefault,
    this.cornerRadius = AppearanceUiRange.cornerRadiusDefault,
  })  : lightTokens = lightTokens ?? ThemeTokens.presets[ThemePreset.light]!,
        darkTokens = darkTokens ?? ThemeTokens.defaults,
        lightPackId =
            lightPackId ?? ThemeColorPack.builtInId(ThemePreset.light),
        darkPackId =
            darkPackId ?? ThemeColorPack.builtInId(ThemePreset.darkModern);

  factory AppearanceSettings.defaults() => AppearanceSettings();

  final AppThemeModeSetting mode;
  final ThemeTokens lightTokens;
  final ThemeTokens darkTokens;
  final String lightPackId;
  final String darkPackId;
  final List<ThemeColorPack> customPacks;

  /// Runtime [FontLoader] family id (or a bundled name like Roboto). Null = system.
  final String? fontFamily;

  /// Durable font file path used to re-register [fontFamily] on launch.
  final String? fontPath;

  final double fontSize;
  final double cornerRadius;

  List<ThemeColorPack> get colorPacks => [
        ...ThemeColorPack.builtIns,
        ...customPacks,
      ];

  ThemeColorPack? packById(String id) {
    for (final pack in colorPacks) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  ThemeTokens tokensFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTokens : lightTokens;

  String packIdFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkPackId : lightPackId;

  bool isEffectivelyDark(Brightness platformBrightness) => switch (mode) {
        AppThemeModeSetting.dark => true,
        AppThemeModeSetting.light => false,
        AppThemeModeSetting.system => platformBrightness == Brightness.dark,
      };

  ThemeTokens activeTokens(Brightness platformBrightness) =>
      tokensFor(isEffectivelyDark(platformBrightness)
          ? Brightness.dark
          : Brightness.light);

  String activePackId(Brightness platformBrightness) => packIdFor(
        isEffectivelyDark(platformBrightness)
            ? Brightness.dark
            : Brightness.light,
      );

  AppearanceSettings copyWith({
    AppThemeModeSetting? mode,
    ThemeTokens? lightTokens,
    ThemeTokens? darkTokens,
    String? lightPackId,
    String? darkPackId,
    List<ThemeColorPack>? customPacks,
    String? fontFamily,
    String? fontPath,
    double? fontSize,
    double? cornerRadius,
    bool clearFont = false,
  }) {
    return AppearanceSettings(
      mode: mode ?? this.mode,
      lightTokens: lightTokens ?? this.lightTokens,
      darkTokens: darkTokens ?? this.darkTokens,
      lightPackId: lightPackId ?? this.lightPackId,
      darkPackId: darkPackId ?? this.darkPackId,
      customPacks: customPacks ?? this.customPacks,
      fontFamily: clearFont ? null : fontFamily ?? this.fontFamily,
      fontPath: clearFont ? null : fontPath ?? this.fontPath,
      fontSize: fontSize ?? this.fontSize,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'lightTokens': lightTokens.toJson(),
        'darkTokens': darkTokens.toJson(),
        'lightPackId': lightPackId,
        'darkPackId': darkPackId,
        'customPacks': customPacks.map((p) => p.toJson()).toList(),
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontPath != null) 'fontPath': fontPath,
        'fontSize': fontSize,
        'cornerRadius': cornerRadius,
      };

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    var fontFamily = json.optionalString('fontFamily');
    var fontPath = json.optionalString('fontPath');
    if (fontFamily == null && fontPath == null) {
      final typeface = json.optionalString('typeface');
      if (typeface == 'sans') {
        fontFamily = 'Roboto';
      }
    }

    final customRaw = json.optionalList('customPacks');
    final custom = <ThemeColorPack>[];
    for (final item in customRaw) {
      if (item is! Map) continue;
      custom.add(
        ThemeColorPack.fromJson(Map<String, dynamic>.from(item)),
      );
    }

    final lightMap = json.optionalMap('lightTokens');
    final darkMap = json.optionalMap('darkTokens');
    if (lightMap != null || darkMap != null) {
      return AppearanceSettings(
        mode: AppThemeModeSettingX.parse(json.optionalString('mode')),
        lightTokens: lightMap != null
            ? ThemeTokens.fromJson(lightMap)
            : ThemeTokens.presets[ThemePreset.light]!,
        darkTokens: darkMap != null
            ? ThemeTokens.fromJson(darkMap)
            : ThemeTokens.defaults,
        lightPackId: json.optionalString('lightPackId') ??
            ThemeColorPack.builtInId(ThemePreset.light),
        darkPackId: json.optionalString('darkPackId') ??
            ThemeColorPack.builtInId(ThemePreset.darkModern),
        customPacks: custom,
        fontFamily: fontFamily,
        fontPath: fontPath,
        fontSize: _parseFontSize(json['fontSize'] ?? json['fontScale']),
        cornerRadius: _parseCornerRadius(json['cornerRadius']),
      );
    }

    // Legacy single-preset → dual slots (NativeTavern-style memory).
    final legacy = _legacyPreset(json.optionalString('preset'));
    return AppearanceSettings(
      mode: AppThemeModeSettingX.parse(json.optionalString('mode')),
      lightTokens: ThemeTokens.presets[ThemePreset.light]!,
      darkTokens: ThemeTokens.presets[legacy] ?? ThemeTokens.defaults,
      lightPackId: ThemeColorPack.builtInId(ThemePreset.light),
      darkPackId: ThemeColorPack.builtInId(legacy),
      fontFamily: fontFamily,
      fontPath: fontPath,
      fontSize: _parseFontSize(json['fontSize'] ?? json['fontScale']),
      cornerRadius: _parseCornerRadius(json['cornerRadius']),
    );
  }

  static ThemePreset _legacyPreset(String? raw) => switch (raw) {
        'slate' => ThemePreset.slate,
        'mist' => ThemePreset.light,
        'black' => ThemePreset.cursorDark,
        'midnight' => ThemePreset.midnight,
        _ => ThemePreset.darkModern,
      };

  static double _snapFontSize(double value) {
    final step = AppearanceUiRange.fontSizeStep;
    final snapped = (value / step).round() * step;
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
