import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/app/project_change_notifier.dart';
import 'package:anoworld/app/visual_image_job_controller.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/domain/ai/visual/visual_image_pipeline.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_actions.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_asset.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );
  const image = AiImageEndpoint(
    kind: AiImageProviderKind.comfyui,
    baseUrl: 'http://localhost:8188',
  );
  final plan = VisualPromptPlan(
    stylePrefix: 'anime',
    negativePrompt: 'worst quality',
    characters: [
      for (final member in sample.cast)
        CharacterVisualPrompt(
          characterId: member.id,
          name: member.name,
          visualTags: 'tags',
          portraitPrompt: 'portrait of ${member.name}',
        ),
    ],
    scenes: [
      for (final node in sample.main.nodes)
        SceneVisualPrompt(
          nodeId: node.id,
          title: node.title,
          scenePrompt: 'scene of ${node.title}',
        ),
    ],
  );

  late Directory dir;
  late _FakePipeline pipeline;
  late MemoryProjectRepository repo;
  late ProjectChangeNotifier changes;
  late VisualImageJobController jobs;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('aw_visual_job');
    pipeline = _FakePipeline();
    repo = _TempDirRepository(
      directory: dir.path,
      seed: {sample.meta.id: sample},
    );
    changes = ProjectChangeNotifier();
    jobs = VisualImageJobController(
      projects: repo,
      changes: changes,
      pipeline: () => pipeline,
    );
  });

  tearDown(() {
    jobs.dispose();
    changes.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  bool startBatch() => jobs.startBatch(
    projectId: sample.meta.id,
    project: sample,
    image: image,
    plan: plan,
    busyLabel: '正在出图…',
    doneLabel: '图片已写入故事',
  );

  test('progress is readable while the run goes and cleared after', () async {
    expect(jobs.isRunning(sample.meta.id), isFalse);
    expect(startBatch(), isTrue);
    await pumpEventQueue();
    expect(jobs.jobOf(sample.meta.id)?.status, '正在出图…');
    expect(jobs.jobOf(sample.meta.id)?.progress, isNull);

    pipeline.emit('正在画立绘：少年', 0.25);
    expect(jobs.jobOf(sample.meta.id)?.status, '正在画立绘：少年');
    expect(jobs.jobOf(sample.meta.id)?.progress, 0.25);

    pipeline.finish(sample);
    await pumpEventQueue();

    expect(jobs.isRunning(sample.meta.id), isFalse);
    expect(jobs.jobOf(sample.meta.id), isNull);
    expect(jobs.takeNotice(sample.meta.id), '图片已写入故事');
    // One-shot: a page that already toasted does not see it again.
    expect(jobs.takeNotice(sample.meta.id), isNull);
  });

  test('the run outlives its starter and still writes the story', () async {
    expect(startBatch(), isTrue);
    await pumpEventQueue();
    final staged = sample.copyWith(
      cast: [
        sample.cast.first.copyWith(avatarAssetId: 'avatar_c_hero'),
        sample.cast[1],
      ],
      assets: const [
        ProjectAsset(
          id: 'avatar_c_hero',
          kind: ProjectAssetKind.avatar,
          relativePath: 'avatars/c_hero.png',
        ),
      ],
    );

    pipeline.finish(staged);
    await pumpEventQueue();

    final saved = await repo.open(sample.meta.id);
    expect(saved.castById('c_hero')!.avatarAssetId, 'avatar_c_hero');
    expect(changes.revisionOf(sample.meta.id), 1);
  });

  test('a second run for the same story is refused', () async {
    expect(startBatch(), isTrue);
    await pumpEventQueue();
    expect(startBatch(), isFalse);

    pipeline.finish(sample);
    await pumpEventQueue();
    expect(startBatch(), isTrue);
  });

  test('a failed run keeps the reason for the page', () async {
    expect(startBatch(), isTrue);
    await pumpEventQueue();
    pipeline.fail(const VisualImageException('生图服务没开'));
    await pumpEventQueue();

    expect(jobs.isRunning(sample.meta.id), isFalse);
    expect(jobs.takeNotice(sample.meta.id), '生图服务没开');
    expect(changes.revisionOf(sample.meta.id), 0);
  });

  test('one-picture redraw saves the prompt and hands back the file', () async {
    pipeline.onAvatar = (project, projectDir, characterId) async {
      await ProjectAssetFiles.writePng(
        projectDir: projectDir,
        assetId: 'avatar_$characterId',
        kind: ProjectAssetKind.avatar,
        relativePath: ProjectAssetFiles.avatarRelativePath(characterId),
        bytes: _pngBytes,
      );
      return project.copyWith(
        cast: [
          for (final member in project.cast)
            member.id == characterId
                ? member.copyWith(avatarAssetId: 'avatar_$characterId')
                : member,
        ],
        assets: [
          for (final asset in project.assets)
            if (asset.id != 'avatar_$characterId') asset,
          ProjectAsset(
            id: 'avatar_$characterId',
            kind: ProjectAssetKind.avatar,
            relativePath: ProjectAssetFiles.avatarRelativePath(characterId),
          ),
        ],
      );
    };
    final edited = plan.copyWith(
      characters: [
        for (final row in plan.characters)
          row.characterId == 'c_hero'
              ? row.copyWith(portraitPrompt: 'fresh prompt')
              : row,
      ],
    );

    final file = await jobs.redrawOne(
      projectId: sample.meta.id,
      image: image,
      plan: edited,
      prompt: 'fresh prompt',
      target: VisualPromptTarget.portrait,
      characterId: 'c_hero',
      busyLabel: '正在重画…',
      doneLabel: '图片已更新',
    );

    expect(file, isNotNull);
    expect(file!.existsSync(), isTrue);
    final saved = await repo.open(sample.meta.id);
    expect(saved.castById('c_hero')!.portraitPrompt, contains('fresh prompt'));
    expect(saved.castById('c_hero')!.avatarAssetId, 'avatar_c_hero');
    expect(jobs.takeNotice(sample.meta.id), '图片已更新');
    expect(jobs.isRunning(sample.meta.id), isFalse);
  });
}

/// Pipeline stand-in: the test decides when (and how) the run ends.
class _FakePipeline extends VisualImagePipeline {
  Future<Project> Function(Project project, String projectDir, String id)?
  onAvatar;

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

  void emit(String message, double? progress) => _progress?.call(message, progress);

  void finish(Project project) => _run?.complete(project);

  void fail(Object error) => _run?.completeError(error);

  @override
  Future<Project> regenerateAvatar({
    required Project project,
    required String projectDir,
    required AiImageEndpoint image,
    required String characterId,
    String? prompt,
    String? negative,
  }) {
    final handler = onAvatar;
    if (handler == null) throw UnimplementedError();
    return handler(project, projectDir, characterId);
  }
}

/// Memory library that reports a real folder, so pictures resolve on disk.
class _TempDirRepository extends MemoryProjectRepository {
  _TempDirRepository({required this.directory, super.seed});

  final String directory;

  @override
  Future<String?> directoryFor(String projectId) async => directory;
}

/// Contents are irrelevant: the redraw only has to leave a file behind.
final Uint8List _pngBytes = Uint8List.fromList(const <int>[1, 2, 3, 4]);
