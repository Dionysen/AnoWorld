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
    this.opacity = AppDialogueChrome.defaultOpacity,
  });

  /// Fixed body lines per dialogue page; longer text pages on.
  final int lines;

  final double fontSize;

  /// `#RRGGBB` fill; empty follows the theme surface.
  final String backgroundHex;

  /// Glass fill alpha, [AppDialogueChrome.minOpacity]–[maxOpacity].
  final double opacity;

  bool get followsTheme => backgroundHex.isEmpty;

  VnUiSettings copyWith({
    int? lines,
    double? fontSize,
    String? backgroundHex,
    double? opacity,
  }) {
    return VnUiSettings(
      lines: lines ?? this.lines,
      fontSize: fontSize ?? this.fontSize,
      backgroundHex: backgroundHex ?? this.backgroundHex,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lines': lines,
    'fontSize': fontSize,
    'backgroundHex': backgroundHex,
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
        other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(lines, fontSize, backgroundHex, opacity);
}
