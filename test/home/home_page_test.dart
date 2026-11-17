import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home shows bottom nav for saves and works', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('存档'), findsWidgets);
    expect(find.text('作品'), findsWidgets);
    expect(find.text('还没有存档'), findsOneWidget);
  });

  testWidgets('works tab lists seeded projects and opens hub', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
      idGenerator: () => 'p_new',
    );

    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('作品').last);
    await tester.pumpAndSettle();

    expect(find.text('雨夜投宿'), findsOneWidget);
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();

    expect(find.text('开始游玩'), findsOneWidget);
    expect(find.text('少年离家，雨夜投宿。'), findsOneWidget);
  });

  testWidgets('works more can switch display mode', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final display = await testLibraryDisplay();
    await tester.pumpWidget(testApp(projects: repo, libraryDisplay: display));
    await tester.pumpAndSettle();

    await tester.tap(find.text('作品').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('作品选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紧凑网格'));
    await tester.pumpAndSettle();

    expect(display.prefs.viewMode, LibraryViewMode.compactGrid);
    expect(find.text('雨夜投宿'), findsOneWidget);
  });

  testWidgets('blank create opens project hub from works fab sheet', (
    tester,
  ) async {
    final repo = MemoryProjectRepository(idGenerator: () => 'p_blank');
    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('作品').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('开始创作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建空白作品').last);
    await tester.pumpAndSettle();

    expect(find.text('未命名作品'), findsWidgets);
    expect(find.text('开始游玩'), findsOneWidget);
  });

  testWidgets('settings capsule opens settings with section nav', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    // Bottom extra capsule (not a top-bar icon).
    expect(find.byTooltip('设置'), findsNothing);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('通用'), findsWidgets);
    expect(find.text('外观'), findsWidgets);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('关于'), findsWidgets);
  });

  testWidgets('create entry opens from works sheet', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('作品').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('开始创作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('粘贴故事'));
    await tester.pumpAndSettle();

    expect(find.text('这条创作路径马上就好'), findsOneWidget);
  });

  testWidgets('saves tab lists progress and opens hub', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final projects = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final saves = MemorySaveRepository(
      seed: {
        sample.meta.id: SaveSlot(
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.utc(2026, 1, 2),
        ),
      },
    );

    await tester.pumpWidget(testApp(projects: projects, saves: saves));
    await tester.pumpAndSettle();

    expect(find.text('雨夜投宿'), findsWidgets);
    await tester.tap(find.text('雨夜投宿').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('继续'), findsWidgets);
  });

  testWidgets('hub start play opens runtime', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始游玩'));
    await tester.pumpAndSettle();

    expect(find.text('视觉小说'), findsOneWidget);
    expect(find.text('该走了。'), findsOneWidget);
  });
}
