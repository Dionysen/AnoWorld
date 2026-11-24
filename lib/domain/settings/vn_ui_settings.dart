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

  /// Panel-to-stage rim inset as a multiple of [fontSize].
  final double outerInsetRatio;

  bool get followsTheme => backgroundHex.isEmpty;

  bool get textFollowsTheme => textHex.isEmpty;

  bool get typewriterEnabled => textSpeed > 0;

  /// Fills inset defaults when prefs predate them or after a hot reload.
  static VnUiSettings resolved(VnUiSettings raw) {
    double inner;
    double outer;
    try {
      inner = raw.innerInsetRatio;
      outer = raw.outerInsetRatio;
    } on TypeError {
      return VnUiSettings(
        lines: raw.lines,
        fontSize: raw.fontSize,
        textSpeed: raw.textSpeed,
        backgroundHex: raw.backgroundHex,
        textHex: raw.textHex,
        opacity: raw.opacity,
      );
    }
    final clampedInner = _clampDouble(
      inner,
      AppDialogueChrome.minInsetRatio,
      AppDialogueChrome.maxInsetRatio,
    );
    final clampedOuter = _clampDouble(
      outer,
      AppDialogueChrome.minInsetRatio,
      AppDialogueChrome.maxInsetRatio,
    );
    if (clampedInner == inner && clampedOuter == outer) return raw;
    return raw.copyWith(
      innerInsetRatio: clampedInner,
      outerInsetRatio: clampedOuter,
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
      };

  factory VnUiSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VnUiSettings();
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
      outerInsetRatio: _clampDouble(
        (json.optionalNum('outerInsetRatio') ??
                AppDialogueChrome.defaultOuterInsetRatio)
            .toDouble(),
        AppDialogueChrome.minInsetRatio,
        AppDialogueChrome.maxInsetRatio,
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
        other.outerInsetRatio == outerInsetRatio;
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
      );
}