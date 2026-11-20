import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/text/token_estimator.dart';

/// What a play turn actually gets from the story's reference material.
///
/// Three tiers, no per-token cleverness:
/// - must-in: `alwaysOn` entries (基调 / 硬规则);
/// - hit: entries whose `keys` appear in the recent scene text;
/// - out: the rest stays home — the create assistant can still read it.
class PlayContextSelection {
  const PlayContextSelection({
    required this.loreText,
    required this.plotText,
    required this.alwaysOnTitles,
    required this.hitEntryTitles,
    required this.plotKeywords,
    required this.skippedEntryCount,
  });

  /// World-book blocks, always-on first; empty when nothing was selected.
  final String loreText;

  /// Plot-element block for the elements the scene mentions; empty when none.
  final String plotText;

  final List<String> alwaysOnTitles;
  final List<String> hitEntryTitles;
  final List<String> plotKeywords;

  /// Non-always-on entries whose keys did not match this turn.
  final int skippedEntryCount;

  int get entryCount => alwaysOnTitles.length + hitEntryTitles.length;
}

/// Picks the must-in and hit context for one play turn.
///
/// Pure and IO-free; matching is plain case-insensitive substring over a tail
/// window of the recent scene text. Keep it dumb: this runs on every turn.
class PlayContextSelector {
  const PlayContextSelector({
    this.maxHitEntries = 6,
    this.maxHitPlotElements = 4,
    this.scanTailChars = 2000,
  });

  /// Cap on keyword-hit world-book entries.
  final int maxHitEntries;

  /// Cap on keyword-hit plot elements.
  final int maxHitPlotElements;

  /// Only the last N characters of recent text are scanned.
  final int scanTailChars;

  PlayContextSelection select({
    required Project project,
    PlotElementCatalog? plotCatalog,
    Iterable<String> recentText = const <String>[],
    int? maxTokens,
  }) {
    final window = _window(recentText);
    final always = <WorldBookEntry>[
      for (final entry in project.worldBook.entries)
        if (entry.alwaysOn) entry,
    ];
    // Always-on entries are never sacrificed: they are the hard rules.
    var spent = TokenEstimator.estimate(project.worldBook.textOf(always));
    final hits = _matchEntries(project.worldBook.entries, window);
    final shownHits = <WorldBookEntry>[];
    for (final hit in hits) {
      if (shownHits.length >= maxHitEntries) break;
      if (maxTokens != null) {
        final cost = TokenEstimator.estimate(
          WorldBook.formatEntry(hit.entry),
        );
        if (spent + cost > maxTokens) continue;
        spent += cost;
      }
      shownHits.add(hit.entry);
    }
    final lore = project.worldBook.textOf(<WorldBookEntry>[
      ...always,
      ...shownHits,
    ]);
    spent = TokenEstimator.estimate(lore);

    final plotRows = <PlotElement>[];
    if (plotCatalog != null) {
      for (final element in _plotCandidates(project, plotCatalog, window)) {
        if (plotRows.length >= maxHitPlotElements) break;
        if (maxTokens != null) {
          final cost = TokenEstimator.estimate(
            plotCatalog.promptBlockFor(<PlotElement>[...plotRows, element]),
          );
          if (spent + cost > maxTokens) continue;
        }
        plotRows.add(element);
      }
    }
    final plot = plotCatalog == null
        ? ''
        : plotCatalog.promptBlockFor(plotRows);

    final selection = PlayContextSelection(
      loreText: lore,
      plotText: plot,
      alwaysOnTitles: <String>[for (final e in always) e.title],
      hitEntryTitles: <String>[for (final e in shownHits) e.title],
      plotKeywords: <String>[for (final e in plotRows) e.keyword],
      skippedEntryCount:
          project.worldBook.entries.length - always.length - shownHits.length,
    );
    _log(selection, total: project.worldBook.entries.length);
    return selection;
  }

  List<_ScoredEntry> _matchEntries(
    List<WorldBookEntry> entries,
    String window,
  ) {
    final scored = <_ScoredEntry>[];
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.alwaysOn) continue;
      final tokens = _tokensOf(entry);
      if (tokens.isEmpty) continue;
      var score = 0;
      for (final token in tokens) {
        if (window.contains(token)) score++;
      }
      if (score > 0) scored.add(_ScoredEntry(entry, score, index));
    }
    // Strongest match first; ties keep book order (List.sort is not stable).
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
    return scored;
  }

  /// Match tokens: the entry's keys; an entry with no keys falls back to its
  /// title so a story that never filled keys still pulls lore in.
  static List<String> _tokensOf(WorldBookEntry entry) {
    final keys = <String>[
      for (final key in entry.keys)
        if (key.trim().isNotEmpty) key.trim().toLowerCase(),
    ];
    if (keys.isNotEmpty) return keys;
    final title = entry.title.trim().toLowerCase();
    return title.isEmpty ? const <String>[] : <String>[title];
  }

  List<PlotElement> _plotCandidates(
    Project project,
    PlotElementCatalog catalog,
    String window,
  ) {
    final out = <PlotElement>[];
    for (final element in catalog.resolveSelected(
      project.plotElements.selectedIds,
    )) {
      final keyword = element.keyword.trim().toLowerCase();
      if (keyword.isEmpty || !window.contains(keyword)) continue;
      out.add(element);
    }
    return out;
  }

  String _window(Iterable<String> recentText) {
    final joined = recentText
        .where((t) => t.trim().isNotEmpty)
        .join('\n')
        .toLowerCase();
    if (joined.length <= scanTailChars) return joined;
    return joined.substring(joined.length - scanTailChars);
  }

  static void _log(PlayContextSelection selection, {required int total}) {
    if (total == 0) return;
    AppLog.instance.info(
      '本回合注入设定 ${selection.entryCount}/$total 条'
      '（常驻 ${selection.alwaysOnTitles.length}，命中 ${selection.hitEntryTitles.length}，'
      '跳过 ${selection.skippedEntryCount}）、剧情元素 ${selection.plotKeywords.length} 项',
      tag: 'play.context',
    );
  }
}

class _ScoredEntry {
  const _ScoredEntry(this.entry, this.score, this.index);

  final WorldBookEntry entry;
  final int score;
  final int index;
}
