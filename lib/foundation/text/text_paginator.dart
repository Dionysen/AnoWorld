import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Characters that read as a natural break after them (CJK punctuation + space).
const Set<String> _breakAfter = <String>{
  ' ',
  '\t',
  '\n',
  '，',
  '。',
  '！',
  '？',
  '；',
  '：',
  '、',
  '…',
  '）',
  '」',
  '』',
  '”',
};

/// Splits [text] into pages that each fit within [maxLines] at [maxWidth].
///
/// Measures with [TextPainter] using the same [style], [textScaler] and
/// [textDirection] the page renders with. Breaks prefer whitespace or CJK
/// punctuation near the cut so a word is rarely split mid-way.
List<String> paginateText(
  String text, {
  required TextStyle style,
  required double maxWidth,
  required int maxLines,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
}) {
  if (text.isEmpty || maxWidth <= 0 || maxLines <= 0) {
    return <String>[text];
  }
  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: maxLines,
  );
  final pages = <String>[];
  var rest = text;
  while (rest.isNotEmpty) {
    painter.text = TextSpan(text: rest, style: style);
    painter.layout(maxWidth: maxWidth);
    if (!painter.didExceedMaxLines) {
      pages.add(rest);
      break;
    }
    final fit = _fitLength(painter, rest, style, maxWidth);
    final cut = _cutIndex(rest, fit);
    final page = rest.substring(0, cut).trimRight();
    if (page.isNotEmpty) pages.add(page);
    rest = rest.substring(cut).trimLeft();
  }
  return pages.isEmpty ? <String>[text] : pages;
}

/// Longest prefix of [text] that does not exceed the painter's line budget.
int _fitLength(
  TextPainter painter,
  String text,
  TextStyle style,
  double maxWidth,
) {
  var low = 1;
  var high = text.length;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    painter.text = TextSpan(text: text.substring(0, mid), style: style);
    painter.layout(maxWidth: maxWidth);
    if (painter.didExceedMaxLines) {
      high = mid - 1;
    } else {
      low = mid;
    }
  }
  return low;
}

/// Pulls the cut back to a readable break point without splitting a glyph pair.
int _cutIndex(String text, int fit) {
  final lowest = math.max(1, fit - 24);
  var cut = fit;
  for (var i = fit; i >= lowest; i--) {
    if (_breakAfter.contains(text[i - 1])) {
      cut = i;
      break;
    }
  }
  final unit = text.codeUnitAt(cut - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) cut -= 1;
  return cut < 1 ? 1 : cut;
}
