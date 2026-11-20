import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ProjectFactory();

  Project blank() => factory.createBlank(id: 'p_1', title: '仙宗密录');

  MainStory threeStations() => const MainStory(
        summary: '三站测试图',
        startNodeId: 'n_1',
        nodes: <StoryNode>[
          StoryNode(id: 'n_1', title: '开场', beatIds: <String>[]),
          StoryNode(id: 'n_2', title: '上山', beatIds: <String>[]),
          StoryNode(id: 'n_3', title: '结局', beatIds: <String>[]),
        ],
        edges: <StoryEdge>[
          StoryEdge(
            id: 'e_1',
            from: 'n_1',
            to: 'n_2',
            kind: EdgeKind.defaultEdge,
          ),
          StoryEdge(
            id: 'e_2',
            from: 'n_2',
            to: 'n_3',
            kind: EdgeKind.defaultEdge,
          ),
        ],
        beats: <Beat>[],
      );

  test('editor saving its own layer keeps a graph written meanwhile', () async {
    final repo = MemoryProjectRepository(seed: {'p_1': blank()});
    final pageCopy = await repo.open('p_1');

    // Create assistant writes the graph after the page opened.
    await saveProjectMerged(
      repo,
      'p_1',
      (latest) => latest.copyWith(main: threeStations()),
    );

    // The stale page copy only knows its own layer (cast).
    await saveProjectMerged(
      repo,
      'p_1',
      (latest) => latest.copyWith(
        cast: const <CastMember>[CastMember(id: 'c_1', name: '船夫')],
      ),
    );

    final stored = await repo.open('p_1');
    expect(stored.main.nodes.length, 3);
    expect(pageCopy.main.nodes.length, 1);
    expect(stored.cast.single.name, '船夫');
  });

  test('assistant write keeps a cast added while the turn was running',
      () async {
    final repo = MemoryProjectRepository(seed: {'p_1': blank()});
    final turnCopy = await repo.open('p_1');

    await saveProjectMerged(
      repo,
      'p_1',
      (latest) => latest.copyWith(
        cast: const <CastMember>[CastMember(id: 'c_1', name: '船夫')],
      ),
    );

    // The turn started before the cast change and only owns the graph.
    await saveProjectMerged(
      repo,
      'p_1',
      (latest) => latest.copyWith(main: threeStations()),
    );

    final stored = await repo.open('p_1');
    expect(turnCopy.cast, isEmpty);
    expect(stored.main.nodes.length, 3);
    expect(stored.cast.single.name, '船夫');
  });
}
