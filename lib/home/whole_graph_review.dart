import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/home/patch_review_sheet.dart';

/// Shared whole-graph (`main.replace`) review rows for the create assistant
/// and the main-graph one-click generate button.
class WholeGraphReview {
  const WholeGraphReview._();

  static const replaceRowId = 'replace';

  /// One group with a single tickable rewrite row (stations listed under it).
  static PatchReviewGroup group({
    required AppStrings strings,
    required Project project,
    required MainStory next,
  }) {
    final branches = next.edges.where((e) => e.kind == EdgeKind.branch).length;
    final bits = <String>[strings.stopCount(next.nodes.length)];
    if (branches > 0) bits.add(strings.branchCount(branches));
    final note = <String>[bits.join(' · ')];
    if (project.main.hasAuthoredNodes) {
      note.add(
        project.main.beats.isNotEmpty
            ? strings.replaceStopsWithBeats(
                project.main.nodes.length,
                project.main.beats.length,
              )
            : strings.replaceStops(project.main.nodes.length),
      );
    }
    if (next.summary.trim().isNotEmpty) note.add(next.summary.trim());
    return PatchReviewGroup(
      title: strings.assistantTargetGraph,
      rows: [
        PatchReviewRow(
          id: replaceRowId,
          title: strings.generatedPlotTitle,
          note: note.join('\n'),
          details: [for (final node in next.nodes) nodeLine(node)],
        ),
      ],
    );
  }

  static Set<String> get defaultSelection => {replaceRowId};

  /// One station line in the whole-graph review row.
  static String nodeLine(StoryNode node) {
    final synopsis = node.synopsis?.trim() ?? '';
    final ending = node.tags.contains('ending') ? ' · 终局' : '';
    return synopsis.isEmpty
        ? '· ${node.title}$ending'
        : '· ${node.title}$ending — $synopsis';
  }
}
