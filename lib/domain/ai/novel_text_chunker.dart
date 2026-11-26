/// Slices pasted / imported novel text into windows for map-reduce outline.
class NovelTextScope {
  const NovelTextScope({
    required this.text,
    required this.usedChars,
    required this.totalChars,
    required this.truncated,
  });

  /// Truncated body used for chunking (may equal the full source).
  final String text;
  final int usedChars;
  final int totalChars;
  final bool truncated;
}

class NovelTextChunker {
  const NovelTextChunker({
    this.maxTotalChars = 60000,
    this.windowChars = 5000,
    this.overlapChars = 400,
  });

  final int maxTotalChars;
  final int windowChars;
  final int overlapChars;

  /// Caps the source and reports how much was kept.
  NovelTextScope scope(String raw) {
    final source = raw.trim();
    final total = source.length;
    if (total == 0) {
      return const NovelTextScope(
        text: '',
        usedChars: 0,
        totalChars: 0,
        truncated: false,
      );
    }
    if (total <= maxTotalChars) {
      return NovelTextScope(
        text: source,
        usedChars: total,
        totalChars: total,
        truncated: false,
      );
    }
    return NovelTextScope(
      text: source.substring(0, maxTotalChars),
      usedChars: maxTotalChars,
      totalChars: total,
      truncated: true,
    );
  }

  /// Sliding windows over [scoped] text. Empty input → empty list.
  List<String> chunk(String scoped) {
    final text = scoped.trim();
    if (text.isEmpty) return const [];
    final window = windowChars < 1 ? 1 : windowChars;
    final overlap = overlapChars.clamp(0, window - 1);
    final step = window - overlap;
    final out = <String>[];
    var start = 0;
    while (start < text.length) {
      final end = (start + window).clamp(0, text.length);
      out.add(text.substring(start, end));
      if (end >= text.length) break;
      start += step;
    }
    return out;
  }

  /// Scope then chunk in one call.
  ({NovelTextScope scope, List<String> chunks}) prepare(String raw) {
    final scoped = scope(raw);
    return (scope: scoped, chunks: chunk(scoped.text));
  }
}
