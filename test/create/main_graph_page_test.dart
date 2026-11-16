import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/graph/graph_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  testWidgets('auto layout button rearranges stations', (tester) async {
    final blank = const ProjectFactory().createBlank(
      id: 'p_layout',
      title: '排版',
      now: DateTime.utc(2026, 1, 1),
    );
    final messy = blank.copyWith(
      main: MainStory(
        summary: blank.main.summary,
        startNodeId: 'n_a',
        nodes: const [
          StoryNode(
            id: 'n_a',
            title: '甲',
            beatIds: [],
            layout: NodeLayout(x: 400, y: 200),
          ),
          StoryNode(
            id: 'n_b',
            title: '乙',
            beatIds: [],
            layout: NodeLayout(x: 40, y: 40),
            tags: ['ending'],
          ),
        ],
        edges: const [
          StoryEdge(
            id: 'e_ab',
            from: 'n_a',
            to: 'n_b',
            kind: EdgeKind.defaultEdge,
          ),
        ],
        beats: const [],
      ),
    );
    final repo = MemoryProjectRepository(
      seed: {messy.meta.id: messy},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: MainGraphPage(projectId: messy.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('整理排版'), findsOneWidget);
    await tester.tap(find.byTooltip('整理排版'));
    await tester.pumpAndSettle();

    final opened = await repo.open(messy.meta.id);
    final ax = opened.main.nodeById('n_a')!.layout!.x;
    final bx = opened.main.nodeById('n_b')!.layout!.x;
    expect(ax, lessThan(bx));
  });

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
    expect(find.text('开场'), findsOneWidget);
    expect(find.text('转折'), findsOneWidget);
    expect(find.text('画布'), findsOneWidget);
    expect(find.text('卡片'), findsOneWidget);

    await tester.tap(find.byTooltip('加一站'));
    await tester.pumpAndSettle();
    expect(find.text('新情节'), findsOneWidget);

    final opened = await repo.open(sample.meta.id);
    expect(opened.main.nodes.length, greaterThan(sample.main.nodes.length));
  });

  testWidgets('dragging output port connects two stations', (tester) async {
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
            layout: NodeLayout(x: 40, y: 80),
          ),
          StoryNode(
            id: 'n_b',
            title: '下一站',
            synopsis: '去别处',
            beatIds: [],
            layout: NodeLayout(x: 260, y: 80),
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

    expect(
      find.byKey(const ValueKey('graph_port_out_n_a___pending__')),
      findsOneWidget,
    );
    await tester.timedDrag(
      find.byKey(const ValueKey('graph_port_out_n_a___pending__')),
      const Offset(60, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    final opened = await repo.open(withTwo.meta.id);
    expect(opened.main.edges, isNotEmpty);
    expect(opened.main.edges.first.from, 'n_a');
    expect(opened.main.edges.first.to, 'n_b');
  });

  testWidgets('pending port can fork to a second station', (tester) async {
    final blank = const ProjectFactory().createBlank(
      id: 'p_fork',
      title: '分叉',
      now: DateTime.utc(2026, 1, 1),
    );
    final withThree = blank.copyWith(
      main: MainStory(
        summary: blank.main.summary,
        startNodeId: 'n_a',
        nodes: const [
          StoryNode(
            id: 'n_a',
            title: '分岔口',
            synopsis: '两条路',
            beatIds: [],
            layout: NodeLayout(x: 40, y: 100),
          ),
          StoryNode(
            id: 'n_b',
            title: '左路',
            synopsis: '向左',
            beatIds: [],
            layout: NodeLayout(x: 280, y: 40),
            tags: ['ending'],
          ),
          StoryNode(
            id: 'n_c',
            title: '右路',
            synopsis: '向右',
            beatIds: [],
            layout: NodeLayout(x: 280, y: 180),
            tags: ['ending'],
          ),
        ],
        edges: const [
          StoryEdge(
            id: 'e_ab',
            from: 'n_a',
            to: 'n_b',
            kind: EdgeKind.defaultEdge,
          ),
        ],
        beats: const [],
      ),
    );
    final repo = MemoryProjectRepository(
      seed: {withThree.meta.id: withThree},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: MainGraphPage(projectId: withThree.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('graph_port_out_n_a_e_ab')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('graph_port_out_n_a___pending__')),
      findsOneWidget,
    );

    await tester.timedDrag(
      find.byKey(const ValueKey('graph_port_out_n_a___pending__')),
      const Offset(80, 40),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    final opened = await repo.open(withThree.meta.id);
    expect(opened.main.edges.length, 2);
    expect(
      opened.main.edges.where((e) => e.from == 'n_a').length,
      2,
    );
    expect(
      opened.main.edges.any((e) => e.to == 'n_c' && e.kind == EdgeKind.branch),
      isTrue,
    );
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
    expect(find.byType(GraphViewport), findsOneWidget);

    await tester.tap(find.text('卡片'));
    await tester.pumpAndSettle();
    expect(find.text('画布'), findsOneWidget);
    expect(find.text('卡片'), findsOneWidget);
    expect(find.text('全图'), findsOneWidget);
    expect(find.byType(GraphViewport), findsOneWidget);
    expect(find.text('城门'), findsWidgets);
    final focused = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(focused.panEnabled, isFalse);
    expect(focused.scaleEnabled, isFalse);

    await tester.tap(find.text('全图'));
    await tester.pumpAndSettle();
    expect(find.text('走向全览'), findsNothing);

    await tester.tap(find.text('画布'));
    await tester.pumpAndSettle();
    expect(find.byType(GraphViewport), findsOneWidget);
    final free = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(free.panEnabled, isTrue);
    expect(free.scaleEnabled, isTrue);

    await tester.tap(find.text('全图'));
    await tester.pumpAndSettle();
    expect(find.text('走向全览'), findsOneWidget);

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

    await tester.tap(find.byTooltip('编辑选中'));
    await tester.pumpAndSettle();

    expect(find.text('这一站'), findsOneWidget);
    expect(find.text('本站目标'), findsOneWidget);
    expect(find.text('种类'), findsOneWidget);
    expect(find.text('开场'), findsWidgets);
  });

  testWidgets('tapping output title opens edge editor', (tester) async {
    final blank = const ProjectFactory().createBlank(
      id: 'p_edge_edit',
      title: '边编辑',
      now: DateTime.utc(2026, 1, 1),
    );
    final withEdge = blank.copyWith(
      main: MainStory(
        summary: blank.main.summary,
        startNodeId: 'n_a',
        nodes: const [
          StoryNode(
            id: 'n_a',
            title: '起点',
            synopsis: '开始',
            beatIds: [],
            layout: NodeLayout(x: 40, y: 80),
          ),
          StoryNode(
            id: 'n_b',
            title: '终点',
            synopsis: '结束',
            beatIds: [],
            layout: NodeLayout(x: 280, y: 80),
            tags: ['ending'],
          ),
        ],
        edges: const [
          StoryEdge(
            id: 'e_ab',
            from: 'n_a',
            to: 'n_b',
            kind: EdgeKind.defaultEdge,
            label: '敲门',
            detail: '雨夜',
          ),
        ],
        beats: const [],
      ),
    );
    final repo = MemoryProjectRepository(
      seed: {withEdge.meta.id: withEdge},
    );
    final fake = _RecordingTextClient();
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        textClient: fake,
        home: MainGraphPage(projectId: withEdge.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('graph_port_title_n_a_e_ab')),
    );
    await tester.pumpAndSettle();

    expect(find.text('这条路'), findsOneWidget);
    expect(find.text('详细说明'), findsOneWidget);
    expect(find.text('让 AI 写详细一点'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '轻敲木门');
    await tester.pump();
    final save = find.text('保存');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final opened = await repo.open(withEdge.meta.id);
    expect(opened.main.edges.single.label, '轻敲木门');
    expect(opened.main.edges.single.detail, '雨夜');
  });
}

class _RecordingTextClient implements AiTextClient {
  @override
  Future<String> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
  }) async =>
      '展开后的说明';
}
