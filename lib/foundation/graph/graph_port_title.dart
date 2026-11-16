import 'dart:math' as math;

import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:characters/characters.dart';

/// Display rules for output port title buttons on the canvas.
abstract final class GraphPortTitle {
  /// Max visible characters before ellipsis.
  static const int maxChars = 15;

  static const double minNodeWidth = 148;
  static const double maxNodeWidth = 320;

  /// Approx glyph width for [labelMedium]-sized CJK / Latin mix.
  static const double _charWidth = 13;

  static const double _buttonPadH = AppTheme.spaceSm * 2;
  static const double _bodyPadH = AppTheme.spaceSm * 2;
  static const double _inputReserve = 44;
  static const double _rowGap = AppTheme.spaceXs;

  /// Truncates to [maxChars] characters; appends `…` when clipped.
  static String display(
    String? label, {
    bool pending = false,
    String emptyWired = '未命名',
    String emptyPending = '添加',
  }) {
    final raw = label?.trim() ?? '';
    final full = raw.isEmpty ? (pending ? emptyPending : emptyWired) : raw;
    final chars = full.characters;
    if (chars.length <= maxChars) return full;
    return '${chars.take(maxChars)}…';
  }

  /// Card width from the longest displayed port title (+ input column).
  static double widthForTitles(
    Iterable<String> displayTitles, {
    bool hasInputLabel = false,
  }) {
    var longest = 1;
    for (final title in displayTitles) {
      longest = math.max(longest, title.characters.length);
    }
    final titleBlock = longest * _charWidth + _buttonPadH;
    final left = hasInputLabel ? _inputReserve : AppTheme.spaceSm;
    final width = left + _rowGap + titleBlock + _bodyPadH;
    return width.clamp(minNodeWidth, maxNodeWidth).toDouble();
  }
}
