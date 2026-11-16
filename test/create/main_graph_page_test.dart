import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  testWidgets('canvas shows stations and can add a station', (tester) async {
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: MainGraphPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('城门'), findsOneWidget);
    expect(find.text('客栈'), findsOneWidget);
    expect(find.text('小屏卡片'), findsOneWidget);

    await tester.tap(find.text('加一站'));
    await tester.pumpAndSettle();
    expect(find.text('新情节'), findsOneWidget);

    final opened = await repo.open(sample.meta.id);
    expect(opened.main.nodes.length, greaterThan(sample.main.nodes.length));
  });

  testWidgets('linking two stations adds an edge to main', (tester) async {
    final blank = const ProjectFactory().createBlank(
      id: 'p_link',
      title: '连线',
      now: DateTime.utc(2026, 1, 1),
    );
    final withTwo = blank.copyWith(
      main: MainStory(
        summary: blank.main.summary,
        startNodeId: 'n_a',
        nodes: const [
          StoryNode(
            id: 'n_a',
            title: '开场',
            synopsis: '开始',
            beatIds: [],
            layout: NodeLayout(x: 40, y: 40),
          ),
          StoryNode(
            id: 'n_b',
            title: '下一站',
            synopsis: '去别处',
            beatIds: [],
            layout: NodeLayout(x: 220, y: 40),
            tags: ['ending'],
          ),
        ],
        edges: const [],
        beats: const [],
      ),
    );
    final repo = MemoryProjectRepository(
      seed: {withTwo.meta.id: withTwo},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: MainGraphPage(projectId: withTwo.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.south_east).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一站'));
    await tester.pumpAndSettle();

    final opened = await repo.open(withTwo.meta.id);
    expect(opened.main.edges, isNotEmpty);
    expect(opened.main.edges.first.from, 'n_a');
    expect(opened.main.edges.first.to, 'n_b');
  });

  testWidgets('card mode toggles without losing graph', (tester) async {
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: MainGraphPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    final before = (await repo.open(sample.meta.id)).main;
    await tester.tap(find.text('小屏卡片'));
    await tester.pumpAndSettle();
    expect(find.text('画布'), findsOneWidget);
    expect(find.text('城门'), findsWidgets);

    await tester.tap(find.text('画布'));
    await tester.pumpAndSettle();
    expect(find.text('小屏卡片'), findsOneWidget);

    final after = (await repo.open(sample.meta.id)).main;
    expect(after.nodes.map((n) => n.id), before.nodes.map((n) => n.id));
    expect(after.edges.map((e) => e.id), before.edges.map((e) => e.id));
  });

  testWidgets('edit selected opens station sheet', (tester) async {
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: MainGraphPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('编辑选中'));
    await tester.pumpAndSettle();

    expect(find.text('这一站'), findsOneWidget);
    expect(find.text('本站目标'), findsOneWidget);
    expect(find.text('连出去'), findsOneWidget);
  });
}
