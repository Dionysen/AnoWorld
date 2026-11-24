import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/world_book_editor_page.dart';
import 'package:anoworld/data/folder/memory_project_folder_repository.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project_folder.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/layout/app_pane_width.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:anoworld/home/save_detail_pane.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:anoworld/settings/about_panel.dart';
import 'package:anoworld/settings/persona_settings_page.dart';
import 'package:anoworld/settings/settings_section_view.dart';
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
    expect(find.text('设置'), findsWidgets);
    expect(find.text('还没有进行中的会话'), findsOneWidget);
  });

  testWidgets('works tab lists seeded projects and opens hub', (tester) async {
    // Narrow window: tapping a story still pushes the full page.
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

  testWidgets('me tab lists settings entries that open their own page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    // Settings live in the tab itself — no separate gear entry any more.
    expect(find.byTooltip('设置'), findsNothing);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();

    expect(find.text('当前服务商'), findsWidgets);
    expect(find.text('生图 AI'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppStringsSetup.fallback.appVersion(AppAbout.version)),
      findsOneWidget,
    );
  });

  testWidgets('me tab current user opens persona hub', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置').last);
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
    // Narrow window: tapping a save still opens its play session.
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    // Visual-novel play has no title bar; the stage controls are the landmark.
    expect(find.byTooltip('游玩设置'), findsOneWidget);
    expect(find.byTooltip('保存进度'), findsNothing);
  });

  testWidgets('hub start play opens runtime', (tester) async {
    // Narrow window: tapping a story still pushes the full page.
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(find.text('你扮演谁'), findsOneWidget);
    await tester.tap(find.text('少年').last);
    await tester.pumpAndSettle();

    expect(find.text('该走了。'), findsOneWidget);
    expect(find.byTooltip('保存进度'), findsNothing);
  });

  testWidgets('wide works tab shows the story page beside the list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(seed: {sample.meta.id: sample});

    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();

    // Nothing selected yet: the detail column keeps its width and hints.
    expect(find.text('选一个故事看详情'), findsOneWidget);

    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();

    // The third column is the story page itself — the same page a narrow
    // window pushes — not a preview card of it.
    expect(find.text('选一个故事看详情'), findsNothing);
    expect(find.byType(ProjectHubPage), findsOneWidget);
    expect(find.text('世界书'), findsOneWidget);
    expect(find.text('情节走向'), findsOneWidget);
    expect(find.byTooltip('开始游玩'), findsOneWidget);

    // Geometry: rail | 1px divider | 400 master | 6px handle | detail.
    final detailWidth = tester.getSize(find.byType(ProjectHubPage)).width;
    expect(
      detailWidth,
      closeTo(
        1200 -
            AppLayout.railWidth -
            AppLayout.paneDividerWidth -
            AppLayout.masterPaneDefaultWidth -
            AppLayout.paneResizeHandleWidth,
        0.5,
      ),
    );
  });

  testWidgets('wide works tab keeps the selection across a narrow window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(seed: {sample.meta.id: sample});

    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectHubPage), findsOneWidget);

    // Shrinking collapses back to one column without losing the selection.
    await tester.binding.setSurfaceSize(const Size(420, 800));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectHubPage), findsNothing);
    expect(find.text('雨夜投宿'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectHubPage), findsOneWidget);
  });

  testWidgets('wide works tab divider drag updates the shared width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final paneWidth = AppPaneWidthController();
    await tester.pumpWidget(testApp(paneWidth: paneWidth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey<String>('app_master_detail_handle')),
      const Offset(90, 0),
    );
    await tester.pumpAndSettle();

    expect(
      paneWidth.masterPaneWidth,
      greaterThan(AppLayout.masterPaneDefaultWidth),
    );
  });

  testWidgets('wide sessions tab summarizes the save beside the list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final projects = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final saves = MemorySaveRepository(
      seed: {
        'slot_a': SaveSlot(
          id: 'slot_a',
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.now().toUtc(),
          mode: PlayViewMode.visualNovel,
        ),
      },
    );

    await tester.pumpWidget(testApp(projects: projects, saves: saves));
    await tester.pumpAndSettle();

    expect(find.text('选一条存档看详情'), findsOneWidget);

    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();

    // Play is full-screen, so the column shows the save's summary instead of
    // squeezing the stage in.
    expect(find.text('选一条存档看详情'), findsNothing);
    expect(find.byType(SaveDetailPane), findsOneWidget);
    expect(find.byType(PlaySessionPage), findsNothing);
    expect(find.text('继续游玩'), findsOneWidget);
    expect(find.text('打开故事'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SaveDetailPane)).width,
      closeTo(
        1200 -
            AppLayout.railWidth -
            AppLayout.paneDividerWidth -
            AppLayout.masterPaneDefaultWidth -
            AppLayout.paneResizeHandleWidth,
        0.5,
      ),
    );
  });

  testWidgets('wide sessions tab resumes the save full-screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final projects = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final saves = MemorySaveRepository(
      seed: {
        'slot_a': SaveSlot(
          id: 'slot_a',
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.now().toUtc(),
          mode: PlayViewMode.visualNovel,
        ),
      },
    );

    await tester.pumpWidget(testApp(projects: projects, saves: saves));
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续游玩'));
    await tester.pumpAndSettle();

    // The stage covers the whole window — rail and all — not just the column.
    expect(find.byType(PlaySessionPage), findsOneWidget);
    expect(find.byTooltip('游玩设置'), findsOneWidget);
    expect(
      tester.getSize(find.byType(PlaySessionPage)),
      const Size(1200, 800),
    );
  });

  testWidgets('wide sessions tab opens the story in the stories tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final projects = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final saves = MemorySaveRepository(
      seed: {
        'slot_a': SaveSlot(
          id: 'slot_a',
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.now().toUtc(),
          mode: PlayViewMode.visualNovel,
        ),
      },
    );

    await tester.pumpWidget(testApp(projects: projects, saves: saves));
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开故事'));
    await tester.pumpAndSettle();

    // Handed off to the stories tab, already selected: one page, one home.
    expect(find.byType(ProjectHubPage), findsOneWidget);
    expect(find.text('选一个故事看详情'), findsNothing);
    expect(find.byType(SaveDetailPane), findsNothing);
    expect(find.text('世界书'), findsOneWidget);
    // The rail now marks 故事 as the active destination.
    expect(
      tester.getTopLeft(find.byType(ProjectHubPage)).dx,
      greaterThan(AppLayout.railWidth),
    );
  });

  testWidgets('narrow sessions menu opens the story in the stories tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final projects = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final saves = MemorySaveRepository(
      seed: {
        'slot_a': SaveSlot(
          id: 'slot_a',
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.now().toUtc(),
          mode: PlayViewMode.visualNovel,
        ),
      },
    );

    await tester.pumpWidget(testApp(projects: projects, saves: saves));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开故事'));
    await tester.pumpAndSettle();

    // No pushed copy of the story page: the shell switched to 故事 instead.
    expect(find.byType(ProjectHubPage), findsOneWidget);
    expect(find.text('世界书'), findsOneWidget);
    expect(find.byTooltip('游玩设置'), findsNothing);
  });

  testWidgets('opening a save story enters its folder in the stories tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final now = DateTime.utc(2026, 1, 1);
    final folders = MemoryProjectFolderRepository(
      folders: [
        ProjectFolder(id: 'f_volume', name: '第一卷', createdAt: now),
        ProjectFolder(
          id: 'f_rain',
          name: '雨夜',
          parentId: 'f_volume',
          createdAt: now,
        ),
      ],
      memberships: {sample.meta.id: 'f_rain'},
    );
    final saves = MemorySaveRepository(
      seed: {
        'slot_a': SaveSlot(
          id: 'slot_a',
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.now().toUtc(),
          mode: PlayViewMode.visualNovel,
        ),
      },
    );

    await tester.pumpWidget(
      testApp(
        projects: MemoryProjectRepository(seed: {sample.meta.id: sample}),
        saves: saves,
        folders: folders,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开故事'));
    await tester.pumpAndSettle();

    // The stories tab opened the folder that holds it, so the list beside the
    // pane shows where the story actually lives.
    expect(find.byType(ProjectHubPage), findsOneWidget);
    expect(find.text('第一卷'), findsOneWidget);
    expect(find.text('雨夜'), findsOneWidget);
    expect(find.text('选一个故事看详情'), findsNothing);
  });

  testWidgets('wide play tab opens the chosen entry inside the pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('玩法').last);
    await tester.pumpAndSettle();

    expect(find.text('选一个入口看内容'), findsOneWidget);

    await tester.tap(find.text('剧情元素'));
    await tester.pumpAndSettle();

    expect(find.byType(PlotElementsLibraryPage), findsOneWidget);
    expect(find.text('选一个入口看内容'), findsNothing);
    // The pane owns navigation, so the embedded page drops its back arrow.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('wide me tab previews the selected identity', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(find.text('选一个身份或设置看详情'), findsOneWidget);

    await tester.tap(find.text('User'));
    await tester.pumpAndSettle();

    // Same page a narrow tap pushes: the identity hub, in the third column.
    expect(find.text('选一个身份或设置看详情'), findsNothing);
    expect(find.byType(PersonaSettingsPage), findsOneWidget);
    // Page title + add action live on the identity hub, not the settings list.
    expect(find.text('玩家身份'), findsOneWidget);
    expect(find.text('添加身份'), findsOneWidget);
  });

  testWidgets('wide me tab opens a settings section inside the pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    // The section page lives in the third column; the list stays visible.
    expect(find.byType(SettingsSectionView), findsOneWidget);
    expect(find.text('选一个身份或设置看详情'), findsNothing);
    expect(find.text('AI'), findsOneWidget);
    // The pane owns navigation, so the embedded page drops its back arrow.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('system back deselects the detail pane before leaving', (    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(seed: {sample.meta.id: sample});

    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectHubPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Back closed the story pane, not the window.
    expect(find.byType(ProjectHubPage), findsNothing);
    expect(find.text('选一个故事看详情'), findsOneWidget);
  });

  testWidgets('back closes the page opened inside the detail column first', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(seed: {sample.meta.id: sample});

    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('故事').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();

    // World book is the hub's first section, so its edit button is the first.
    await tester.tap(find.byTooltip('编辑').first);
    await tester.pumpAndSettle();
    expect(find.byType(WorldBookEditorPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // First back pops the editor; the split and its selection stay.
    expect(find.byType(WorldBookEditorPage), findsNothing);
    expect(find.byType(ProjectHubPage), findsOneWidget);
    expect(find.text('选一个故事看详情'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('选一个故事看详情'), findsOneWidget);
  });

  testWidgets('the split fits exactly at its narrowest width', (tester) async {
    // Shell = rail + 1px + contentMinWidth, so both panes sit on their minimum.
    await tester.binding.setSurfaceSize(
      const Size(
        AppLayout.railWidth +
            AppLayout.paneDividerWidth +
            AppLayout.masterPaneMinWidth +
            AppLayout.paneResizeHandleWidth +
            AppLayout.detailPaneMinWidth,
        700,
      ),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('玩法').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('剧情元素'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PlotElementsLibraryPage), findsOneWidget);
    expect(
      tester.getSize(find.byType(PlotElementsLibraryPage)).width,
      closeTo(AppLayout.detailPaneMinWidth, 0.5),
    );
  });

  testWidgets('the saved session fits the narrowest split', (tester) async {
    await tester.binding.setSurfaceSize(
      const Size(
        AppLayout.railWidth +
            AppLayout.paneDividerWidth +
            AppLayout.masterPaneMinWidth +
            AppLayout.paneResizeHandleWidth +
            AppLayout.detailPaneMinWidth,
        700,
      ),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final projects = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    final saves = MemorySaveRepository(
      seed: {
        'slot_narrow': SaveSlot(
          id: 'slot_narrow',
          projectId: sample.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
          savedAt: DateTime.now().toUtc(),
          mode: PlayViewMode.visualNovel,
        ),
      },
    );

    await tester.pumpWidget(testApp(projects: projects, saves: saves));
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SaveDetailPane), findsOneWidget);
    expect(
      tester.getSize(find.byType(SaveDetailPane)).width,
      closeTo(AppLayout.detailPaneMinWidth, 0.5),
    );
  });

  testWidgets('play started inside a story pane still fills the window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(seed: {sample.meta.id: sample});

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
    await tester.tap(find.text('少年').last);
    await tester.pumpAndSettle();

    // Same rule as the sessions tab: the stage leaves the column and covers
    // the window, rail included.
    expect(
      tester.getSize(find.byType(PlaySessionPage)),
      const Size(1200, 800),
    );
  });
}
