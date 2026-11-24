import 'package:anoworld/app/l10n/app_strings_zh.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/home/whole_graph_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('whole-graph review lists stations and defaults to replace', () {
    const strings = AppStringsZh();
    final project = const ProjectFactory().createRainNightSample();
    const next = MainStory(
      summary: '新骨架',
      startNodeId: 'n1',
      nodes: [
        StoryNode(id: 'n1', title: '开场', synopsis: '醒来', beatIds: []),
        StoryNode(
          id: 'n2',
          title: '结局',
          synopsis: '告别',
          beatIds: [],
          tags: ['ending'],
        ),
      ],
      edges: [
        StoryEdge(
          id: 'e1',
          from: 'n1',
          to: 'n2',
          kind: EdgeKind.branch,
          label: '离开',
        ),
      ],
      beats: [],
    );

    final group = WholeGraphReview.group(
      strings: strings,
      project: project,
      next: next,
    );

    expect(group.title, strings.assistantTargetGraph);
    expect(group.rows, hasLength(1));
    expect(group.rows.single.id, WholeGraphReview.replaceRowId);
    expect(group.rows.single.title, strings.generatedPlotTitle);
    expect(group.rows.single.note, contains('2 站'));
    expect(group.rows.single.note, contains('新骨架'));
    expect(group.rows.single.details, contains('· 开场 — 醒来'));
    expect(group.rows.single.details, contains('· 结局 · 终局 — 告别'));
    expect(
      WholeGraphReview.defaultSelection,
      contains(WholeGraphReview.replaceRowId),
    );
  });
}
