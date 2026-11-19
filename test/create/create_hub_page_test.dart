import 'package:anoworld/create/world_book_editor_page.dart';
import 'package:anoworld/create/cast_editor_page.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/create/plot_elements_pick_page.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  testWidgets('create hub lists four edit entries', (tester) async {
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: CreateHubPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('创作·雨夜投宿'), findsOneWidget);
    expect(find.text('改设定、角色与情节走向'), findsNothing);
    expect(find.text('世界书'), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('情节走向'), findsOneWidget);
    expect(find.text('剧情元素'), findsOneWidget);
  });

  testWidgets('create hub subtitles show counts and token size', (tester) async {
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: CreateHubPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(RegExp(r'^\d+ 条设定，\d+ 条常驻，\d+ token$')),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'^\d+ 个角色，\d+ token$')),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'^\d+ 个节点，\d+ token$')),
      findsOneWidget,
    );
    expect(find.text('还没选'), findsOneWidget);
  });

  testWidgets('create hub opens background / cast / main', (tester) async {
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: CreateHubPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openAndBack(String label, Type pageType) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(pageType), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateHubPage), findsOneWidget);
    }

    await openAndBack('世界书', WorldBookEditorPage);
    await openAndBack('角色', CastEditorPage);
    await openAndBack('剧情元素', PlotElementsPickPage);

    await tester.tap(find.text('情节走向'));
    await tester.pumpAndSettle();
    expect(find.byType(MainGraphPage), findsOneWidget);
  });
}