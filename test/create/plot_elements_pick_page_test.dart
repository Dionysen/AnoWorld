import 'package:anoworld/create/plot_elements_pick_page.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('pick page toggles selection and persists', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: PlotElementsPickPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('勾选进本故事'), findsNothing);
    expect(find.text('还没选'), findsNothing);
    expect(find.text('救助流浪猫'), findsOneWidget);

    await tester.tap(find.text('救助流浪猫'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final saved = await repo.open(sample.meta.id);
    expect(saved.plotElements.selectedIds, contains('pe_stray_cat'));
    expect(find.text('已选 1'), findsOneWidget);
  });

  testWidgets('pick page shows selected count from project', (tester) async {
    final sample = const ProjectFactory()
        .createRainNightSample(now: DateTime.utc(2026, 1, 2))
        .copyWith(
          plotElements: const PlotElementSelection(
            selectedIds: <String>['pe_stray_cat'],
          ),
        );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: PlotElementsPickPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已选 1'), findsOneWidget);
  });

  testWidgets('category tab opens a category page that still toggles', (    tester,
  ) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 3),
    );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );

    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: PlotElementsPickPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();

    expect(find.text('日常'), findsOneWidget);
    expect(find.text('新建分类'), findsNothing);

    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();

    expect(find.text('救助流浪猫'), findsOneWidget);
    expect(find.text('雨夜共伞'), findsOneWidget);

    await tester.tap(find.text('救助流浪猫'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final saved = await repo.open(sample.meta.id);
    expect(saved.plotElements.selectedIds, contains('pe_stray_cat'));
  });

  testWidgets('pack tab applies every element of the pack at once', (
    tester,
  ) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 4),
    );
    final repo = MemoryProjectRepository(seed: {sample.meta.id: sample});
    final settings = testSettingsController();
    await settings.updatePlotElements(
      settings.plotElements.upsertPack(
        const PlotElementPack(
          id: 'pe_pack_pick',
          name: '雨夜包',
          elementIds: ['pe_stray_cat', 'pe_shared_umbrella'],
        ),
      ),
    );

    await tester.pumpWidget(
      testScoped(
        settings: settings,
        projects: repo,
        home: PlotElementsPickPage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('包'));
    await tester.pumpAndSettle();
    expect(find.text('雨夜包'), findsOneWidget);
    expect(find.text('已选 0'), findsNothing);

    await tester.tap(find.text('雨夜包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final saved = await repo.open(sample.meta.id);
    expect(
      saved.plotElements.selectedIds,
      containsAll(<String>['pe_stray_cat', 'pe_shared_umbrella']),
    );
    expect(find.text('已选 2'), findsOneWidget);
    expect(find.text('已选 2 / 2 条'), findsOneWidget);
  });
}
