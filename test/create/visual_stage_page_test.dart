import 'dart:async';

import 'package:anoworld/app/project_change_notifier.dart';import 'package:anoworld/app/visual_image_job_controller.dart';
import 'package:anoworld/create/visual_stage_page.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/visual/visual_image_pipeline.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_actions.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  Future<MemoryProjectRepository> pumpPage(
    WidgetTester tester, {
    Size? viewSize,
  }) async {
    if (viewSize != null) {
      tester.view.physicalSize = viewSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: VisualStagePage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('opens the story right away, no retry needed', (tester) async {
    await pumpPage(tester);

    expect(find.text('无法打开故事'), findsNothing);
    expect(find.text('重试'), findsNothing);
    expect(find.text('一键生成提示词'), findsOneWidget);
    expect(find.text('一键生成图片'), findsOneWidget);
    expect(find.text('画风'), findsOneWidget);
    expect(find.text('角色立绘'), findsOneWidget);
    expect(find.text('场景图'), findsOneWidget);
    expect(find.text('少年'), findsOneWidget);
    expect(find.text('掌柜'), findsOneWidget);
    expect(find.text('城门'), findsOneWidget);
    expect(find.text('客栈'), findsOneWidget);
  });

  testWidgets('rows preview prompts and stand in for missing pictures', (
    tester,
  ) async {
    await pumpPage(tester);

    // Style prefix / negative ship with defaults from the template.
    expect(find.textContaining('very aesthetic'), findsOneWidget);
    expect(find.textContaining('thick outline'), findsOneWidget);
    expect(find.textContaining('worst quality'), findsOneWidget);
    expect(find.text('还没有立绘'), findsNWidgets(2));
    expect(find.text('还没有场景图'), findsNWidgets(2));
  });

  testWidgets('editing a portrait prompt saves on 保存', (tester) async {
    final repo = await pumpPage(tester, viewSize: const Size(900, 1200));

    await tester.tap(find.text('少年'));
    await tester.pumpAndSettle();
    expect(find.text('提示词'), findsOneWidget);
    expect(find.text('立绘朝向'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'masterpiece, 1boy, silver_hair, white background',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final opened = await repo.open(sample.meta.id);
    // Portraits are always saved waist-up, even when the edit omitted framing.
    expect(
      opened.castById('c_hero')!.portraitPrompt,
      'masterpiece, 1boy, silver_hair, upper body, white background',
    );
    // Sheet closed, list row now previews the saved prompt.
    expect(find.text('立绘朝向'), findsNothing);
    expect(
      find.text(
        'masterpiece, 1boy, silver_hair, upper body, white background',
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaving with unsaved edits asks before dropping them', (
    tester,
  ) async {
    await pumpPage(tester, viewSize: const Size(900, 1200));

    await tester.tap(find.text('城门'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'night, city gate');
    await tester.pumpAndSettle();

    // System back while dirty: the editor asks before dropping the edits.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃这次修改？'), findsOneWidget);

    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('night, city gate'), findsOneWidget);
    expect(find.text('提示词'), findsOneWidget);
  });

  testWidgets('facing switch rewrites the portrait direction', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final seeded = sample.copyWith(
      cast: const [
        CastMember(
          id: 'c_hero',
          name: '少年',
          visualTags: '1boy, silver_hair',
          facing: SpriteFacing.right,
        ),
      ],
    );
    final repo = MemoryProjectRepository(seed: {sample.meta.id: seeded});
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: VisualStagePage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('少年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('面向左 · 站右边'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final opened = await repo.open(sample.meta.id);
    final hero = opened.castById('c_hero')!;
    expect(hero.facing, SpriteFacing.left);
    expect(hero.portraitPrompt, contains('facing left'));
    expect(hero.portraitPrompt, isNot(contains('facing right')));
  });

  testWidgets('generating images asks for prompts first', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('一键生成图片'));
    await tester.pumpAndSettle();
    expect(find.text('先生成提示词，再出图'), findsOneWidget);
  });

  testWidgets('narrow viewport keeps both buttons in one row', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    expect(tester.takeException(), isNull);
    final promptButton = tester.getRect(find.text('一键生成提示词'));
    final imageButton = tester.getRect(find.text('一键生成图片'));
    expect(promptButton.center.dy, imageButton.center.dy);
    expect(promptButton.right, lessThan(imageButton.left));
  });

  testWidgets('sheet offers prompt and picture regen per row', (tester) async {
    await pumpPage(tester, viewSize: const Size(900, 1200));

    await tester.tap(find.text('城门'));
    await tester.pumpAndSettle();
    expect(find.text('重新生成提示词'), findsOneWidget);
    expect(find.text('重新生成图片'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Style prefix has no picture: only the prompt action.
    await tester.tap(find.text('画风前缀'));
    await tester.pumpAndSettle();
    expect(find.text('重新生成提示词'), findsOneWidget);
    expect(find.text('重新生成图片'), findsNothing);
  });

  testWidgets('regenerating one prompt only rewrites that field', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = MemoryProjectRepository(seed: {sample.meta.id: sample});
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        textClient: _FakePromptClient(
          'Prompt: "masterpiece, 1boy, red_scarf, white background"',
        ),
        home: VisualStagePage(projectId: sample.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('城门'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新生成提示词'));
    await tester.pumpAndSettle();
    // Model chatter is trimmed down to one prompt line.
    expect(
      find.text('masterpiece, 1boy, red_scarf, white background'),
      findsOneWidget,
    );

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final opened = await repo.open(sample.meta.id);
    expect(
      opened.main.nodeById('n1')!.imagePrompt,
      'masterpiece, 1boy, red_scarf, white background',
    );
    // Sibling scene keeps its own prompt untouched.
    expect(opened.main.nodeById('n2')!.imagePrompt, isNull);
  });

  testWidgets('picture regen needs a prompt, then an image provider', (
    tester,
  ) async {
    await pumpPage(tester, viewSize: const Size(900, 1200));

    await tester.tap(find.text('少年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新生成图片'));
    await tester.pumpAndSettle();
    expect(find.text('先生成提示词，再出图'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'masterpiece, 1boy');
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新生成图片'));
    await tester.pumpAndSettle();
    expect(find.text('先在设置里选好生图服务，填好地址'), findsOneWidget);
    // Placeholder stays: the sheet still has no picture to show.
    expect(find.text('还没有立绘'), findsWidgets);
  });

  test('draft plan keeps empty rows so the list still shows them', () {
    final draft = draftPlanFromProjectFields(sample);
    expect(draft.characters, hasLength(2));
    expect(draft.scenes, hasLength(2));
    expect(draft.isComplete, isFalse);
    expect(planFromProjectFields(sample), isNull);
  });

  test('stored portrait prompt makes a plan drawable without tags', () {
    final project = sample.copyWith(
      cast: const [
        CastMember(id: 'c_hero', name: '少年', portraitPrompt: 'kept prompt'),
      ],
      main: MainStory(
        summary: sample.main.summary,
        startNodeId: 'n1',
        nodes: const [
          StoryNode(
            id: 'n1',
            title: '城门',
            beatIds: <String>[],
            imagePrompt: 'kept scene',
          ),
        ],
        edges: const [],
        beats: const [],
      ),
    );
    final plan = planFromProjectFields(project)!;
    expect(plan.isComplete, isTrue);
    // Older full-body prompts are normalized for drawing without a re-save.
    expect(plan.characters.single.portraitPrompt, contains('kept prompt'));
    expect(plan.characters.single.portraitPrompt, contains('upper body'));
    expect(plan.scenes.single.scenePrompt, 'kept scene');
  });

  test('normalizeVisualPrompt folds model chatter into one line', () {
    expect(
      normalizeVisualPrompt('```\nPrompt: "masterpiece, anime"\n```'),
      'masterpiece, anime',
    );
    expect(
      normalizeVisualPrompt('提示词：1girl,\n  white background\n'),
      '1girl, white background',
    );
    expect(normalizeVisualPrompt('   '), '');
  });

  testWidgets('a picture run keeps going after leaving the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staged = _drawableStory();
    final repo = MemoryProjectRepository(seed: {staged.meta.id: staged});
    final changes = ProjectChangeNotifier();
    final pipeline = _SlowPipeline();
    final jobs = VisualImageJobController(
      projects: repo,
      changes: changes,
      pipeline: () => pipeline,
    );
    addTearDown(jobs.dispose);
    final settings = testSettingsController();
    await settings.updateAi(
      settings.ai.copyWith(
        image: const AiImageEndpoint(
          kind: AiImageProviderKind.comfyui,
          baseUrl: 'http://localhost:8188',
        ),
      ),
    );
    Widget scope(Widget home) => testScoped(
      settings: settings,
      projects: repo,
      projectChanges: changes,
      visualJobs: jobs,
      home: home,
    );

    await tester.pumpWidget(scope(VisualStagePage(projectId: staged.meta.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一键生成图片'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('正在出图'), findsOneWidget);

    pipeline.emit('正在画立绘：少年', 0.5);
    await tester.pump();
    expect(find.text('正在画立绘：少年 · 50%'), findsOneWidget);

    // Leaving the page must not stop the run.
    await tester.pumpWidget(scope(const SizedBox.shrink()));
    await tester.pump();
    expect(jobs.isRunning(staged.meta.id), isTrue);

    // Coming back shows the same run and its live progress.
    await tester.pumpWidget(scope(VisualStagePage(projectId: staged.meta.id)));
    await tester.pump();
    await tester.pump();
    expect(find.text('正在画立绘：少年 · 50%'), findsOneWidget);

    pipeline.finish(
      staged.copyWith(
        cast: [
          staged.cast.first.copyWith(avatarAssetId: 'avatar_c_hero'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBusyIndicator), findsNothing);
    expect(find.text('图片已写入故事'), findsOneWidget);
  });
}

/// One character + one scene, both already carrying prompts to draw.
Project _drawableStory() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );
  return sample.copyWith(
    cast: const [
      CastMember(id: 'c_hero', name: '少年', portraitPrompt: 'kept portrait'),
    ],
    main: MainStory(
      summary: sample.main.summary,
      startNodeId: 'n1',
      nodes: const [
        StoryNode(
          id: 'n1',
          title: '城门',
          beatIds: <String>[],
          imagePrompt: 'kept scene',
        ),
      ],
      edges: const [],
      beats: const [],
    ),
  );
}

/// Pipeline stand-in whose run only ends when the test says so.
class _SlowPipeline extends VisualImagePipeline {
  Completer<Project>? _run;
  VisualProgress? _progress;

  @override
  Future<Project> run({
    required Project project,
    required String projectDir,
    required AiImageEndpoint image,
    required VisualPromptPlan plan,
    bool generateAvatars = true,
    bool generateScenes = true,
    bool? upscale,
    int? steps,
    bool skipExisting = true,
    VisualProgress? onProgress,
  }) {
    _progress = onProgress;
    return (_run = Completer<Project>()).future;
  }

  void emit(String message, double? progress) =>
      _progress?.call(message, progress);

  void finish(Project project) => _run?.complete(project);
}

class _FakePromptClient implements AiTextClient {
  _FakePromptClient(this.reply);

  final String reply;

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    return AiTextCompletion(content: reply);
  }
}
