import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';

/// Visual-novel reading prefs: the stage dialogue box.
///
/// Not global appearance — changing the theme leaves these alone.
class VnUiSettings {
  const VnUiSettings({
    this.lines = AppDialogueChrome.defaultLines,
    this.fontSize = AppDialogueChrome.defaultFontSize,
    this.backgroundHex = '',
    this.textHex = '',
    this.opacity = AppDialogueChrome.defaultOpacity,
  });

  /// Fixed body lines per dialogue page; longer text pages on.
  final int lines;

  final double fontSize;

  /// `#RRGGBB` fill; empty follows the theme surface.
  final String backgroundHex;

  /// `#RRGGBB` body text; empty follows the theme body colour.
  final String textHex;

  /// Glass fill alpha, [AppDialogueChrome.minOpacity]–[maxOpacity].
  final double opacity;

  bool get followsTheme => backgroundHex.isEmpty;

  bool get textFollowsTheme => textHex.isEmpty;

  VnUiSettings copyWith({
    int? lines,
    double? fontSize,
    String? backgroundHex,
    String? textHex,
    double? opacity,
  }) {
    return VnUiSettings(
      lines: lines ?? this.lines,
      fontSize: fontSize ?? this.fontSize,
      backgroundHex: backgroundHex ?? this.backgroundHex,
      textHex: textHex ?? this.textHex,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lines': lines,
    'fontSize': fontSize,
    'backgroundHex': backgroundHex,
    'textHex': textHex,
    'opacity': opacity,
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
      backgroundHex: json.optionalString('backgroundHex') ?? '',
      textHex: json.optionalString('textHex') ?? '',
      opacity: _clampDouble(
        (json.optionalNum('opacity') ?? AppDialogueChrome.defaultOpacity)
            .toDouble(),
        AppDialogueChrome.minOpacity,
        AppDialogueChrome.maxOpacity,
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
        other.backgroundHex == backgroundHex &&
        other.textHex == textHex &&
        other.opacity == opacity;
  }

  @override
  int get hashCode =>
      Object.hash(lines, fontSize, backgroundHex, textHex, opacity);
}
