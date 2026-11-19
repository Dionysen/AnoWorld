import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/project/project_token_estimate.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

Project _emptyProject() {
  final stamp = DateTime.utc(2026, 1, 1);
  return Project(
    meta: ProjectMeta(
      id: 'proj_empty',
      title: '空故事',
      createdAt: stamp,
      updatedAt: stamp,
    ),
    worldBook: const WorldBook(),
    cast: const <CastMember>[],
    main: const MainStory(
      summary: '',
      startNodeId: '',
      nodes: <StoryNode>[],
      edges: <StoryEdge>[],
      beats: <Beat>[],
    ),
  );
}

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  test('sample story has tokens in every section', () {
    final size = ProjectTokenEstimate.of(sample);
    expect(size.worldBook, greaterThan(0));
    expect(size.cast, greaterThan(0));
    expect(size.main, greaterThan(0));
    expect(size.plotElements, 0);
  });

  test('empty story is zero everywhere', () {
    final size = ProjectTokenEstimate.of(_emptyProject());
    expect(size.worldBook, 0);
    expect(size.cast, 0);
    expect(size.main, 0);
    expect(size.plotElements, 0);
  });

  test('plot elements count only the selected rows', () {
    final catalog = PlotElementCatalog(
      custom: const <PlotElement>[
        PlotElement(
          id: 'pe_test',
          keyword: '雨夜',
          description: '雨下到半夜，客栈檐下有灯。',
        ),
      ],
    );
    final withSelection = sample.copyWith(
      plotElements: const PlotElementSelection(selectedIds: <String>['pe_test']),
    );

    final none = ProjectTokenEstimate.of(
      sample,
      plotCatalog: catalog,
    );
    final selected = ProjectTokenEstimate.of(
      withSelection,
      plotCatalog: catalog,
    );

    expect(none.plotElements, 0);
    expect(selected.plotElements, greaterThan(0));
  });

  test('main line text includes summary, nodes, beats and edges', () {
    final text = ProjectTokenEstimate.mainLineText(sample.main);
    expect(text, contains('少年离家，雨夜投宿。'));
    expect(text, contains('城门'));
    expect(text, contains('客栈'));
  });

  test('cast text lists one block per member', () {
    final text = ProjectTokenEstimate.castProfileText(sample.cast);
    expect(text, contains('少年'));
    expect(text, contains('掌柜'));
    expect(text, contains('沉着，话少'));
  });

  group('size lines', () {
    test('world book shows counts and raw tokens', () {
      expect(
        describeWorldBookSize(entries: 12, alwaysOn: 3, tokens: 4210),
        '12 条设定，3 条常驻，4210 token',
      );
      expect(
        describeWorldBookSize(entries: 0, alwaysOn: 0, tokens: 0),
        '还没有设定条目',
      );
    });

    test('cast shows member count and raw tokens', () {
      expect(describeCastSize(members: 2, tokens: 33), '2 个角色，33 token');
      expect(describeCastSize(members: 0, tokens: 0), '还没有角色');
    });

    test('main line shows node count and raw tokens', () {
      expect(describeMainSize(nodes: 2, tokens: 37), '2 个节点，37 token');
      expect(describeMainSize(nodes: 0, tokens: 0), '还没有情节节点');
    });

    test('plot elements show selection and raw tokens', () {
      expect(describePlotElementsSize(selected: 2, tokens: 4210), '已选 2 项，4210 token');
      expect(describePlotElementsSize(selected: 0, tokens: 0), '还没选');
    });
  });
}
