import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/text/token_estimator.dart';

/// Approximate token size of each authoring section of a story.
/// Counts the text the model actually receives: the world book as one
/// injected block, cast profile fields, the plot-element prompt block, and
/// everything written for the main line (summary, nodes, beats, edges).
class ProjectTokenEstimate {
  const ProjectTokenEstimate({
    required this.worldBook,
    required this.cast,
    required this.main,
    required this.plotElements,
  });

  final int worldBook;
  final int cast;
  final int main;
  final int plotElements;

  /// [project] sizes; plot elements need the global [plotCatalog] that
  /// resolves the selected ids, so they stay 0 when it is omitted.
  factory ProjectTokenEstimate.of(
    Project project, {
    PlotElementCatalog? plotCatalog,
  }) {
    return ProjectTokenEstimate(
      worldBook: TokenEstimator.estimate(project.worldBook.combinedText),
      cast: TokenEstimator.estimate(castProfileText(project.cast)),
      main: TokenEstimator.estimate(mainLineText(project.main)),
      plotElements: plotCatalog == null
          ? 0
          : TokenEstimator.estimate(
              plotCatalog.promptBlockForSelected(
                project.plotElements.selectedIds,
              ),
            ),
    );
  }

  /// Name plus profile fields, one block per character.
  static String castProfileText(Iterable<CastMember> cast) {
    final blocks = <String>[];
    for (final member in cast) {
      final parts = <String>[
        member.name.trim(),
        if (member.summary.trim().isNotEmpty) member.summary.trim(),
        if (member.personality.trim().isNotEmpty) member.personality.trim(),
        if (member.speechStyle.trim().isNotEmpty) member.speechStyle.trim(),
        if (member.exampleLines.isNotEmpty)
          member.exampleLines
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .join('\n'),
      ].where((part) => part.isNotEmpty);
      if (parts.isEmpty) continue;
      blocks.add(parts.join('\n'));
    }
    return blocks.join('\n\n');
  }

  /// Summary plus every written node / edge / beat text of the main line.
  static String mainLineText(MainStory main) {
    final parts = <String>[
      if (main.summary.trim().isNotEmpty) main.summary.trim(),
    ];
    for (final node in main.nodes) {
      if (node.title.trim().isNotEmpty) parts.add(node.title.trim());
      final synopsis = node.synopsis?.trim() ?? '';
      if (synopsis.isNotEmpty) parts.add(synopsis);
    }
    for (final edge in main.edges) {
      _addIfAny(parts, edge.label);
      _addIfAny(parts, edge.detail);
    }
    for (final beat in main.beats) {
      _addIfAny(parts, beat.scene.locationText);
      for (final line in beat.lines) {
        _addIfAny(parts, line.text);
      }
      for (final choice in beat.choices) {
        _addIfAny(parts, choice.text);
      }
      _addIfAny(parts, beat.note);
    }
    return parts.join('\n');
  }

  static void _addIfAny(List<String> parts, String? text) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isNotEmpty) parts.add(trimmed);
  }
}
