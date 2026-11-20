import 'package:anoworld/domain/ai/play_context_selector.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

Project _project({
  List<WorldBookEntry> entries = const <WorldBookEntry>[],
  List<String> plotIds = const <String>[],
}) {
  return Project(
    meta: ProjectMeta(
      id: 'p',
      title: '测试故事',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
    worldBook: WorldBook(entries: entries),
    cast: const <CastMember>[],
    main: const MainStory(
      summary: '',
      startNodeId: '',
      nodes: <StoryNode>[],
      edges: <StoryEdge>[],
      beats: <Beat>[],
    ),
    plotElements: PlotElementSelection(selectedIds: plotIds),
  );
}

const _alwaysOn = WorldBookEntry(
  id: 'w_rule',
  title: '基调',
  body: '常年阴雨，人口稀少。',
  alwaysOn: true,
);

const _tavern = WorldBookEntry(
  id: 'w_tavern',
  title: '客栈',
  body: '雨夜客栈只在夜里开门。',
  keys: <String>['客栈', '投宿'],
);

const _ferry = WorldBookEntry(
  id: 'w_ferry',
  title: '渡口',
  body: '渡口入夜停摆，最后一班船在天黑前。',
  keys: <String>['渡口', '船'],
);

const _noKeys = WorldBookEntry(id: 'w_gate', title: '城门', body: '城门日出开、日落闭。');

void main() {
  const selector = PlayContextSelector();

  test('always-on entries go in whether or not the scene mentions them', () {
    final selection = selector.select(
      project: _project(entries: <WorldBookEntry>[_alwaysOn]),
      recentText: const <String>['天晴了'],
    );

    expect(selection.loreText, contains('常年阴雨'));
    expect(selection.alwaysOnTitles, <String>['基调']);
    expect(selection.hitEntryTitles, isEmpty);
    expect(selection.skippedEntryCount, 0);
  });

  test('keyed entries join only when their keys appear', () {
    final project = _project(
      entries: <WorldBookEntry>[_alwaysOn, _tavern, _ferry],
    );

    final quiet = selector.select(
      project: project,
      recentText: const <String>['今天有点冷'],
    );
    expect(quiet.loreText, isNot(contains('雨夜客栈')));
    expect(quiet.loreText, isNot(contains('渡口入夜')));
    expect(quiet.skippedEntryCount, 2);

    final atInn = selector.select(
      project: project,
      recentText: const <String>['我推开客栈的门'],
    );
    expect(atInn.loreText, contains('雨夜客栈'));
    expect(atInn.loreText, contains('常年阴雨'));
    expect(atInn.loreText, isNot(contains('渡口入夜')));
    expect(atInn.hitEntryTitles, <String>['客栈']);
    expect(atInn.skippedEntryCount, 1);
  });

  test('matching ignores ASCII case and reads the newest turns', () {
    final project = _project(
      entries: const <WorldBookEntry>[
        WorldBookEntry(
          id: 'w_bar',
          title: 'BAR',
          body: '柜台后面挂着旧招牌。',
          keys: <String>['Tavern'],
        ),
      ],
    );

    final selection = selector.select(
      project: project,
      recentText: const <String>['We walk into the TAVERN.'],
    );

    expect(selection.loreText, contains('旧招牌'));
  });

  test('entries without keys fall back to their title', () {
    final selection = selector.select(
      project: _project(entries: <WorldBookEntry>[_noKeys]),
      recentText: const <String>['城门那边有人敲钟'],
    );

    expect(selection.hitEntryTitles, <String>['城门']);
  });

  test('caps hits by match strength, then book order', () {
    final project = _project(
      entries: const <WorldBookEntry>[
        WorldBookEntry(id: 'w_a', title: 'A', body: 'A正文', keys: <String>['雨']),
        WorldBookEntry(
          id: 'w_b',
          title: 'B',
          body: 'B正文',
          keys: <String>['雨', '夜'],
        ),
        WorldBookEntry(id: 'w_c', title: 'C', body: 'C正文', keys: <String>['雨']),
      ],
    );

    final all = selector.select(
      project: project,
      recentText: const <String>['雨夜里'],
    );
    expect(all.hitEntryTitles, <String>['B', 'A', 'C']);

    final capped = const PlayContextSelector(maxHitEntries: 2)
        .select(project: project, recentText: const <String>['雨夜里']);
    expect(capped.hitEntryTitles, <String>['B', 'A']);
    expect(capped.skippedEntryCount, 1);
  });

  test('plot elements join only when the scene brings them up', () {
    final catalog = PlotElementCatalog(
      custom: const <PlotElement>[
        PlotElement(
          id: 'pe_rain',
          keyword: '暴雨',
          description: '暴雨封路，逼出临时决定。',
          categoryId: '',
        ),
        PlotElement(
          id: 'pe_letter',
          keyword: '旧信',
          description: '一封旧信揭开旧身份。',
          categoryId: '',
        ),
      ],
    );
    final project = _project(plotIds: const <String>['pe_rain', 'pe_letter']);

    final quiet = selector.select(
      project: project,
      plotCatalog: catalog,
      recentText: const <String>['我们在屋里喝茶'],
    );
    expect(quiet.plotText, isEmpty);
    expect(quiet.plotKeywords, isEmpty);

    final storm = selector.select(
      project: project,
      plotCatalog: catalog,
      recentText: const <String>['外面下起暴雨'],
    );
    expect(storm.plotText, contains('暴雨封路'));
    expect(storm.plotText, isNot(contains('旧信')));
    expect(storm.plotKeywords, <String>['暴雨']);
  });

  test('without a catalog no plot block is produced', () {
    final selection = selector.select(
      project: _project(plotIds: const <String>['pe_rain']),
      recentText: const <String>['暴雨'],
    );

    expect(selection.plotText, isEmpty);
  });

  test('caps plot elements too', () {
    final catalog = PlotElementCatalog(
      custom: const <PlotElement>[
        PlotElement(id: 'pe1', keyword: '雨', description: '一'),
        PlotElement(id: 'pe2', keyword: '雨', description: '二'),
        PlotElement(id: 'pe3', keyword: '雨', description: '三'),
      ],
    );

    final selection = const PlayContextSelector(maxHitPlotElements: 2).select(
      project: _project(plotIds: const <String>['pe1', 'pe2', 'pe3']),
      plotCatalog: catalog,
      recentText: const <String>['下雨了'],
    );

    expect(selection.plotKeywords, <String>['雨', '雨']);
    expect(selection.plotText, contains('一'));
    expect(selection.plotText, isNot(contains('三')));
  });

  test('only the tail of a long transcript is scanned', () {
    final project = _project(entries: <WorldBookEntry>[_ferry]);
    final head = '渡口' * 1;
    final filler = '无关内容' * 600;

    final selection = const PlayContextSelector(scanTailChars: 200)
        .select(project: project, recentText: <String>[head, filler]);

    expect(selection.hitEntryTitles, isEmpty);
  });

  test('an empty story selects nothing', () {
    final selection = selector.select(project: _project());

    expect(selection.entryCount, 0);
    expect(selection.loreText, isEmpty);
    expect(selection.plotText, isEmpty);
    expect(selection.skippedEntryCount, 0);
  });
}
