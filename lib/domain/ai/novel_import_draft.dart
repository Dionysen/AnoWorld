import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/world_book.dart';

/// How much of the pasted/imported text was fed into the pipeline.
class NovelSourceRange {
  const NovelSourceRange({
    required this.usedChars,
    required this.totalChars,
    required this.truncated,
  });

  final int usedChars;
  final int totalChars;
  final bool truncated;

  NovelSourceRange copyWith({
    int? usedChars,
    int? totalChars,
    bool? truncated,
  }) {
    return NovelSourceRange(
      usedChars: usedChars ?? this.usedChars,
      totalChars: totalChars ?? this.totalChars,
      truncated: truncated ?? this.truncated,
    );
  }
}

/// Condensed outline produced before world / cast / main.
class NovelOutline {
  const NovelOutline({
    this.title = '',
    this.summary = '',
    this.conflicts = const <String>[],
  });

  final String title;
  final String summary;
  final List<String> conflicts;

  String get promptBlock {
    final buf = StringBuffer();
    if (title.trim().isNotEmpty) {
      buf.writeln('标题：${title.trim()}');
    }
    if (summary.trim().isNotEmpty) {
      buf.writeln('主线：${summary.trim()}');
    }
    if (conflicts.isNotEmpty) {
      buf.writeln('关键冲突：');
      for (final c in conflicts) {
        final line = c.trim();
        if (line.isEmpty) continue;
        buf.writeln('- $line');
      }
    }
    return buf.toString().trim();
  }

  NovelOutline copyWith({
    String? title,
    String? summary,
    List<String>? conflicts,
  }) {
    return NovelOutline(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      conflicts: conflicts ?? this.conflicts,
    );
  }
}

/// In-memory result of the novel-import pipeline (written only on confirm).
class NovelImportDraft {
  const NovelImportDraft({
    this.title = '',
    this.note = '',
    this.sourceRange = const NovelSourceRange(
      usedChars: 0,
      totalChars: 0,
      truncated: false,
    ),
    this.outline = const NovelOutline(),
    this.worldBook = const WorldBook(),
    this.cast = const <CastMember>[],
    this.main = const MainStory(
      summary: '',
      startNodeId: '',
      nodes: [],
      edges: [],
      beats: [],
    ),
  });

  final String title;
  final String note;
  final NovelSourceRange sourceRange;
  final NovelOutline outline;
  final WorldBook worldBook;
  final List<CastMember> cast;
  final MainStory main;

  bool get hasSkeleton =>
      worldBook.entries.isNotEmpty &&
      cast.isNotEmpty &&
      main.nodes.length >= 2;

  NovelImportDraft copyWith({
    String? title,
    String? note,
    NovelSourceRange? sourceRange,
    NovelOutline? outline,
    WorldBook? worldBook,
    List<CastMember>? cast,
    MainStory? main,
  }) {
    return NovelImportDraft(
      title: title ?? this.title,
      note: note ?? this.note,
      sourceRange: sourceRange ?? this.sourceRange,
      outline: outline ?? this.outline,
      worldBook: worldBook ?? this.worldBook,
      cast: cast ?? this.cast,
      main: main ?? this.main,
    );
  }

  /// Drops a station and edges that touch it; fixes [MainStory.startNodeId].
  NovelImportDraft withoutStation(String nodeId) {
    final nodes = main.nodes.where((n) => n.id != nodeId).toList();
    if (nodes.length == main.nodes.length) return this;
    final edges = main.edges
        .where((e) => e.from != nodeId && e.to != nodeId)
        .toList();
    var start = main.startNodeId;
    if (start == nodeId || nodes.every((n) => n.id != start)) {
      start = nodes.isEmpty ? '' : nodes.first.id;
    }
    return copyWith(
      main: main.copyWith(
        startNodeId: start,
        nodes: nodes,
        edges: edges,
      ),
    );
  }
}
