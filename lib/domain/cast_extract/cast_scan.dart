import 'package:anoworld/domain/models/world_book.dart';

/// One text window worth showing the extractor.
///
/// The scanner only slices the world book; deciding which rows are characters
/// is left to the model, so unusual layouts still flow through.
class CastScanWindow {
  const CastScanWindow({required this.entryTitle, required this.text});

  final String entryTitle;
  final String text;
}

class CastScanResult {
  const CastScanResult({
    this.windows = const <CastScanWindow>[],
    this.totalChars = 0,
    this.scannedEntries = 0,
  });

  final List<CastScanWindow> windows;
  final int totalChars;
  final int scannedEntries;

  bool get isEmpty => windows.isEmpty;
}

/// Slices a [WorldBook] into character-extraction windows.
///
/// Entries that look like rosters (title / keys / body cues) go first, so a
/// tight character budget still covers the likely sources.
class CastScanner {
  const CastScanner({
    this.maxWindowChars = 1200,
    this.maxTotalChars = 60000,
  });

  final int maxWindowChars;
  final int maxTotalChars;

  static final RegExp _rosterTitle = RegExp(
    r'人物|角色|登场|设定|人设|关系|character|persona|people|cast|roster',
    caseSensitive: false,
  );
  static final RegExp _rosterBody = RegExp(
    r'姓名|名字|别名|身份|年龄|性别|外貌|性格|说话|简介|'
    r'name|alias|age|gender|appearance|personality',
    caseSensitive: false,
  );

  CastScanResult scan(WorldBook book) {
    if (book.entries.isEmpty) return const CastScanResult();
    final scored = <_ScoredEntry>[];
    for (var i = 0; i < book.entries.length; i++) {
      final entry = book.entries[i];
      scored.add(_ScoredEntry(index: i, entry: entry, score: _score(entry)));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });

    final windows = <CastScanWindow>[];
    var total = 0;
    for (final row in scored) {
      if (total >= maxTotalChars) break;
      for (final chunk in _chunk(row.entry.body)) {
        if (total + chunk.length > maxTotalChars) {
          total = maxTotalChars;
          break;
        }
        windows.add(
          CastScanWindow(entryTitle: row.entry.title, text: chunk),
        );
        total += chunk.length;
      }
    }
    return CastScanResult(
      windows: windows,
      totalChars: total,
      scannedEntries: book.entries.length,
    );
  }

  int _score(WorldBookEntry entry) {
    var score = 0;
    final titleKeys = '${entry.title} ${entry.keys.join(' ')}';
    if (_rosterTitle.hasMatch(titleKeys)) score += 6;
    final head = entry.body.length > 600
        ? entry.body.substring(0, 600)
        : entry.body;
    if (_rosterBody.hasMatch(head)) score += 3;
    if (head.contains('|')) score += 1;
    return score;
  }

  /// Packs paragraphs into chunks close to [maxWindowChars].
  Iterable<String> _chunk(String body) sync* {
    final paragraphs = body
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    final buffer = StringBuffer();
    var size = 0;
    for (final paragraph in paragraphs) {
      if (paragraph.length > maxWindowChars) {
        if (buffer.isNotEmpty) {
          yield buffer.toString();
          buffer.clear();
          size = 0;
        }
        for (var start = 0; start < paragraph.length; start += maxWindowChars) {
          final end = (start + maxWindowChars).clamp(0, paragraph.length);
          yield paragraph.substring(start, end);
        }
        continue;
      }
      if (size + paragraph.length + 2 > maxWindowChars && buffer.isNotEmpty) {
        yield buffer.toString();
        buffer.clear();
        size = 0;
      }
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(paragraph);
      size += paragraph.length + 2;
    }
    if (buffer.isNotEmpty) yield buffer.toString();
  }
}

class _ScoredEntry {
  const _ScoredEntry({
    required this.index,
    required this.entry,
    required this.score,
  });

  final int index;
  final WorldBookEntry entry;
  final int score;
}
