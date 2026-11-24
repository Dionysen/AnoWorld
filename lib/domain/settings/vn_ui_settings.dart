import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';

/// Visual-novel reading prefs: the stage dialogue box.
///
/// Not global appearance — changing the theme leaves these alone.
class VnUiSettings {
  const VnUiSettings({
    this.lines = AppDialogueChrome.defaultLines,
    this.fontSize = AppDialogueChrome.defaultFontSize,
    this.textSpeed = AppDialogueChrome.defaultTextSpeed,
    this.backgroundHex = '',
    this.textHex = '',
    this.opacity = AppDialogueChrome.defaultOpacity,
    this.innerInsetRatio = AppDialogueChrome.defaultInnerInsetRatio,
    this.outerInsetRatio = AppDialogueChrome.defaultOuterInsetRatio,
    this.controlSizeRatio = AppDialogueChrome.defaultControlSizeRatio,
    this.controlTopGapRatio = AppDialogueChrome.defaultControlTopGapRatio,
    this.controlBottomGapRatio = AppDialogueChrome.defaultControlBottomGapRatio,
  });

  /// Fixed body lines per dialogue page; longer text pages on.
  final int lines;

  final double fontSize;

  /// Typewriter speed in characters per second; 0 shows text instantly.
  final double textSpeed;

  /// `#RRGGBB` fill; empty follows the theme surface.
  final String backgroundHex;

  /// `#RRGGBB` body text; empty follows the theme body colour.
  final String textHex;

  /// Glass fill alpha, [AppDialogueChrome.minOpacity]–[maxOpacity].
  final double opacity;

  /// Text-to-panel rim inset as a multiple of [fontSize].
  final double innerInsetRatio;

  /// Dialogue panel inset from the left and right screen edges (× [fontSize]).
  final double outerInsetRatio;

  /// Bottom control button diameter as a multiple of [fontSize].
  final double controlSizeRatio;

  /// Gap between the dialogue panel and the control row (× [fontSize]).
  final double controlTopGapRatio;

  /// Gap between the control row and the screen bottom (× [fontSize]).
  final double controlBottomGapRatio;

  bool get followsTheme => backgroundHex.isEmpty;

  bool get textFollowsTheme => textHex.isEmpty;

  bool get typewriterEnabled => textSpeed > 0;

  /// Fills defaults when prefs predate a field or after a hot reload.
  static VnUiSettings resolved(VnUiSettings raw) {
    double readRatio(double Function(VnUiSettings s) pick, double fallback) {
      try {
        return pick(raw);
      } on TypeError {
        return fallback;
      }
    }

    final inner = _clampDouble(
      readRatio((s) => s.innerInsetRatio, AppDialogueChrome.defaultInnerInsetRatio),
      AppDialogueChrome.minInsetRatio,
      AppDialogueChrome.maxInsetRatio,
    );
    final outer = _clampDouble(
      readRatio((s) => s.outerInsetRatio, AppDialogueChrome.defaultOuterInsetRatio),
      AppDialogueChrome.minInsetRatio,
      AppDialogueChrome.maxInsetRatio,
    );
    final control = _clampDouble(
      readRatio(
        (s) => s.controlSizeRatio,
        AppDialogueChrome.defaultControlSizeRatio,
      ),
      AppDialogueChrome.minControlSizeRatio,
      AppDialogueChrome.maxControlSizeRatio,
    );
    final topGap = _clampDouble(
      readRatio(
        (s) => s.controlTopGapRatio,
        AppDialogueChrome.defaultControlTopGapRatio,
      ),
      AppDialogueChrome.minControlVerticalGapRatio,
      AppDialogueChrome.maxControlVerticalGapRatio,
    );
    final bottomGap = _clampDouble(
      readRatio(
        (s) => s.controlBottomGapRatio,
        AppDialogueChrome.defaultControlBottomGapRatio,
      ),
      AppDialogueChrome.minControlVerticalGapRatio,
      AppDialogueChrome.maxControlVerticalGapRatio,
    );

    return VnUiSettings(
      lines: raw.lines,
      fontSize: raw.fontSize,
      textSpeed: raw.textSpeed,
      backgroundHex: raw.backgroundHex,
      textHex: raw.textHex,
      opacity: raw.opacity,
      innerInsetRatio: inner,
      outerInsetRatio: outer,
      controlSizeRatio: control,
      controlTopGapRatio: topGap,
      controlBottomGapRatio: bottomGap,
    );
  }

  VnUiSettings copyWith({
    int? lines,
    double? fontSize,
    double? textSpeed,
    String? backgroundHex,
    String? textHex,
    double? opacity,
    double? innerInsetRatio,
    double? outerInsetRatio,
    double? controlSizeRatio,
    double? controlTopGapRatio,
    double? controlBottomGapRatio,
  }) {
    return VnUiSettings(
      lines: lines ?? this.lines,
      fontSize: fontSize ?? this.fontSize,
      textSpeed: textSpeed ?? this.textSpeed,
      backgroundHex: backgroundHex ?? this.backgroundHex,
      textHex: textHex ?? this.textHex,
      opacity: opacity ?? this.opacity,
      innerInsetRatio: innerInsetRatio ?? this.innerInsetRatio,
      outerInsetRatio: outerInsetRatio ?? this.outerInsetRatio,
      controlSizeRatio: controlSizeRatio ?? this.controlSizeRatio,
      controlTopGapRatio: controlTopGapRatio ?? this.controlTopGapRatio,
      controlBottomGapRatio:
          controlBottomGapRatio ?? this.controlBottomGapRatio,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lines': lines,
        'fontSize': fontSize,
        'textSpeed': textSpeed,
        'backgroundHex': backgroundHex,
        'textHex': textHex,
        'opacity': opacity,
        'innerInsetRatio': innerInsetRatio,
        'outerInsetRatio': outerInsetRatio,
        'controlSizeRatio': controlSizeRatio,
        'controlTopGapRatio': controlTopGapRatio,
        'controlBottomGapRatio': controlBottomGapRatio,
      };

  factory VnUiSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VnUiSettings();
    final outerLegacy = _clampDouble(
      (json.optionalNum('outerInsetRatio') ??
              AppDialogueChrome.defaultOuterInsetRatio)
          .toDouble(),
      AppDialogueChrome.minInsetRatio,
      AppDialogueChrome.maxInsetRatio,
    );
    final verticalFallback = json.containsKey('controlTopGapRatio') ||
            json.containsKey('controlBottomGapRatio')
        ? null
        : outerLegacy;
    return VnUiSettings(
      lines: _clampInt(
        (json.optionalNum('lines') ?? AppDialogueChrome.defaultLines).round(),
        AppDialogueChrome.minLines,
        AppDialogueChrome.maxLines,
      ),
      fontSize: _clampDouble(
        (json.optionalNum('fontSize') ?? AppDialogueChrome.defaultFontSize)
            .toDouble(),
        AppDialogueChrome.minFontSize,
        AppDialogueChrome.maxFontSize,
      ),
      textSpeed: _clampDouble(
        (json.optionalNum('textSpeed') ?? AppDialogueChrome.defaultTextSpeed)
            .toDouble(),
        AppDialogueChrome.minTextSpeed,
        AppDialogueChrome.maxTextSpeed,
      ),
      backgroundHex: json.optionalString('backgroundHex') ?? '',
      textHex: json.optionalString('textHex') ?? '',
      opacity: _clampDouble(
        (json.optionalNum('opacity') ?? AppDialogueChrome.defaultOpacity)
            .toDouble(),
        AppDialogueChrome.minOpacity,
        AppDialogueChrome.maxOpacity,
      ),
      innerInsetRatio: _clampDouble(
        (json.optionalNum('innerInsetRatio') ??
                AppDialogueChrome.defaultInnerInsetRatio)
            .toDouble(),
        AppDialogueChrome.minInsetRatio,
        AppDialogueChrome.maxInsetRatio,
      ),
      outerInsetRatio: outerLegacy,
      controlSizeRatio: _clampDouble(
        (json.optionalNum('controlSizeRatio') ??
                AppDialogueChrome.defaultControlSizeRatio)
            .toDouble(),
        AppDialogueChrome.minControlSizeRatio,
        AppDialogueChrome.maxControlSizeRatio,
      ),
      controlTopGapRatio: _clampDouble(
        (json.optionalNum('controlTopGapRatio') ??
                json.optionalNum('controlButtonGapRatio') ??
                verticalFallback ??
                AppDialogueChrome.defaultControlTopGapRatio)
            .toDouble(),
        AppDialogueChrome.minControlVerticalGapRatio,
        AppDialogueChrome.maxControlVerticalGapRatio,
      ),
      controlBottomGapRatio: _clampDouble(
        (json.optionalNum('controlBottomGapRatio') ??
                verticalFallback ??
                AppDialogueChrome.defaultControlBottomGapRatio)
            .toDouble(),
        AppDialogueChrome.minControlVerticalGapRatio,
        AppDialogueChrome.maxControlVerticalGapRatio,
      ),
    );
  }

  static double _clampDouble(double value, double min, double max) =>
      value.clamp(min, max);

  static int _clampInt(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  @override
  bool operator ==(Object other) {
    return other is VnUiSettings &&
        other.lines == lines &&
        other.fontSize == fontSize &&
        other.textSpeed == textSpeed &&
        other.backgroundHex == backgroundHex &&
        other.textHex == textHex &&
        other.opacity == opacity &&
        other.innerInsetRatio == innerInsetRatio &&
        other.outerInsetRatio == outerInsetRatio &&
        other.controlSizeRatio == controlSizeRatio &&
        other.controlTopGapRatio == controlTopGapRatio &&
        other.controlBottomGapRatio == controlBottomGapRatio;
  }

  @override
  int get hashCode => Object.hash(
        lines,
        fontSize,
        textSpeed,
        backgroundHex,
        textHex,
        opacity,
        innerInsetRatio,
        outerInsetRatio,
        controlSizeRatio,
        controlTopGapRatio,
        controlBottomGapRatio,
      );
}