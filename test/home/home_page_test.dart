import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
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

  testWidgets('home shows four bottom nav destinations', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('会话'), findsWidgets);
    expect(find.text('故事'), findsWidgets);
    expect(find.text('玩法'), findsWidgets);
    expect(find.text('我'), findsWidgets);
    expect(find.text('还没有进行中的会话'), findsOneWidget);
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

    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();

    expect(find.text('雨夜投宿'), findsOneWidget);
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('开始游玩'), findsOneWidget);
    expect(find.byTooltip('继续创作'), findsOneWidget);
    expect(find.text('少年离家，雨夜投宿。'), findsWidgets);
    expect(find.text('世界书'), findsOneWidget);
    expect(find.text('情节走向'), findsOneWidget);
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

    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('故事选项'));
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

    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();

    final create = find.byKey(const ValueKey<String>('library_create'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建空白故事'));
    await tester.pumpAndSettle();

    expect(find.text('未命名故事'), findsWidgets);
    expect(find.byTooltip('开始游玩'), findsOneWidget);
  });

  testWidgets('me tab settings opens settings with section nav', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('设置'), findsNothing);
    await tester.tap(find.text('我').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('通用'), findsWidgets);
    expect(find.text('外观'), findsWidgets);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('关于'), findsWidgets);
  });

  testWidgets('me tab current user opens persona hub', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('我').last);
    await tester.pumpAndSettle();

    expect(find.text('User'), findsOneWidget);
    await tester.tap(find.text('User'));
    await tester.pumpAndSettle();

    expect(find.text('玩家身份'), findsWidgets);
    expect(find.text('添加身份'), findsOneWidget);
  });

  testWidgets('create entry opens from works sheet', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey<String>('library_create'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.tap(find.text('粘贴故事'));
    await tester.pumpAndSettle();

    expect(find.text('这条创作路径马上就好'), findsOneWidget);
  });

  testWidgets('saves tab lists progress and resumes play', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final projects = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final saves = MemorySaveRepository(
      seed: {
        'slot_resume': SaveSlot(
          id: 'slot_resume',
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.utc(2026, 1, 2),
          mode: PlayViewMode.visualNovel,
        ),
      },
    );

    await tester.pumpWidget(testApp(projects: projects, saves: saves));
    await tester.pumpAndSettle();

    expect(find.text('雨夜投宿'), findsWidgets);
    await tester.tap(find.text('雨夜投宿').first);
    await tester.pumpAndSettle();
    expect(find.text('雨夜投宿'), findsWidgets);
    expect(find.byTooltip('保存进度'), findsNothing);
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
    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('开始游玩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('视觉小说'));
    await tester.pumpAndSettle();

    expect(find.text('该走了。'), findsOneWidget);
    expect(find.byTooltip('保存进度'), findsNothing);
  });
}
