import 'dart:math' as math;

/// Strips inline `<think>` / `<thinking>` blocks from a streamed reply.
///
/// Chunks can split a tag in half (`"<thi"` + `"nk>"`), so the last few
/// characters are held back until the next chunk proves what they are.
class ThinkTagStreamFilter {
  static final RegExp _openTag = RegExp(
    r'<(thinking|think|thought|reasoning)>',
    caseSensitive: false,
  );
  static final RegExp _closeTag = RegExp(
    r'</(thinking|think|thought|reasoning)>',
    caseSensitive: false,
  );
  static const List<String> _openTags = <String>[
    '<thinking>',
    '<think>',
    '<thought>',
    '<reasoning>',
  ];
  static const List<String> _closeTags = <String>[
    '</thinking>',
    '</think>',
    '</thought>',
    '</reasoning>',
  ];

  final StringBuffer _buffer = StringBuffer();
  bool _inside = false;

  /// Feeds one chunk; returns `(visible, reasoning)` safe to show right now.
  (String, String) add(String chunk) {
    if (chunk.isEmpty) return const ('', '');
    _buffer.write(chunk);
    return _drain(finalFlush: false);
  }

  /// Emits whatever is still buffered once the stream has ended.
  (String, String) flush() => _drain(finalFlush: true);

  (String, String) _drain({required bool finalFlush}) {
    var text = _buffer.toString();
    final visible = StringBuffer();
    final reasoning = StringBuffer();
    while (text.isNotEmpty) {
      if (_inside) {
        final match = _closeTag.firstMatch(text);
        if (match == null) {
          final hold = finalFlush ? 0 : _heldSuffix(text, _closeTags);
          reasoning.write(text.substring(0, text.length - hold));
          text = text.substring(text.length - hold);
          break;
        }
        reasoning.write(text.substring(0, match.start));
        text = text.substring(match.end);
        _inside = false;
      } else {
        final match = _openTag.firstMatch(text);
        if (match == null) {
          final hold = finalFlush ? 0 : _heldSuffix(text, _openTags);
          visible.write(text.substring(0, text.length - hold));
          text = text.substring(text.length - hold);
          break;
        }
        visible.write(text.substring(0, match.start));
        text = text.substring(match.end);
        _inside = true;
      }
    }
    _buffer
      ..clear()
      ..write(text);
    return (visible.toString(), reasoning.toString());
  }

  /// Length of the tail that could still grow into one of [tags].
  static int _heldSuffix(String text, List<String> tags) {
    final lower = text.toLowerCase();
    final maxTag = tags.fold<int>(0, (max, tag) => math.max(max, tag.length));
    final start = math.max(0, lower.length - (maxTag - 1));
    for (var i = lower.length - 1; i >= start; i--) {
      if (lower.codeUnitAt(i) != 0x3C) continue; // '<'
      final suffix = lower.substring(i);
      for (final tag in tags) {
        if (tag.length > suffix.length && tag.startsWith(suffix)) {
          return suffix.length;
        }
      }
    }
    return 0;
  }
}
