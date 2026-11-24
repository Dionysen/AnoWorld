import 'dart:async';
import 'dart:io';

import 'package:anoworld/app/project_change_notifier.dart';
import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/domain/ai/visual/visual_image_pipeline.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_actions.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:flutter/foundation.dart';

/// Live progress of the picture run for one story.
@immutable
class VisualImageJob {
  const VisualImageJob({required this.status, this.progress});

  /// What the pipeline is doing right now (「正在画立绘：少年」…).
  final String status;

  /// 0–1 across the whole run; null when the step has no count.
  final double? progress;
}

/// Owns ComfyUI picture runs so they survive leaving the visuals page.
///
/// The page only starts a run and mirrors [jobOf]; the pipeline, the story
/// write and the toast text all happen here, where the page's disposal cannot
/// cancel them. One run per story at a time — the same GPU backlog twice would
/// only make both halves slower.
class VisualImageJobController extends ChangeNotifier {
  VisualImageJobController({
    required this.projects,
    required this.changes,
    VisualImagePipeline Function()? pipeline,
  }) : _pipeline = pipeline ?? VisualImagePipeline.new;

  /// Story storage the runs read and write.
  final ProjectRepository projects;

  /// Tells open pages that the pictures landed.
  final ProjectChangeNotifier changes;

  final VisualImagePipeline Function() _pipeline;
  final Map<String, _RunningJob> _running = <String, _RunningJob>{};

  /// How the last finished run went, kept until a page shows it once.
  final Map<String, String> _notices = <String, String>{};

  bool _disposed = false;

  /// Mirror of the run in flight for [projectId], or null when it is idle.
  VisualImageJob? jobOf(String projectId) {
    final job = _running[projectId];
    return job == null
        ? null
        : VisualImageJob(status: job.status, progress: job.progress);
  }

  bool isRunning(String projectId) => _running.containsKey(projectId);

  /// Toast for the run that finished while no page was watching; null once.
  String? takeNotice(String projectId) => _notices.remove(projectId);

  /// Draws every missing picture in [plan]. False when a run is already going.
  bool startBatch({
    required String projectId,
    required Project project,
    required AiImageEndpoint image,
    required VisualPromptPlan plan,
    required String busyLabel,
    required String doneLabel,
  }) {
    final job = _begin(projectId, busyLabel);
    if (job == null) return false;
    unawaited(
      _runBatch(
        job,
        projectId: projectId,
        project: project,
        image: image,
        plan: plan,
        doneLabel: doneLabel,
      ),
    );
    return true;
  }

  /// Saves [plan] and redraws one picture with [prompt].
  ///
  /// Returns the fresh file so a still-open sheet can preview it; null when the
  /// story is already drawing or the run failed (the notice says why).
  Future<File?> redrawOne({
    required String projectId,
    required AiImageEndpoint image,
    required VisualPromptPlan plan,
    required String prompt,
    required VisualPromptTarget target,
    required String busyLabel,
    required String doneLabel,
    String? characterId,
    String? nodeId,
  }) async {
    final job = _begin(projectId, busyLabel);
    if (job == null) return null;
    try {
      final projectDir = await _directoryFor(projectId);
      final latest = await saveProjectMerged(
        projects,
        projectId,
        (stored) => applyVisualPromptPlan(stored, plan),
      );
      final pipeline = _pipeline();
      AppLog.instance.info('重画一张画面（$projectId）', tag: 'visual.regen');
      final redrawn = switch (target) {
        VisualPromptTarget.portrait => await pipeline.regenerateAvatar(
          project: latest,
          projectDir: projectDir,
          image: image,
          characterId: characterId!,
          prompt: prompt,
        ),
        VisualPromptTarget.scene => await pipeline.regenerateScene(
          project: latest,
          projectDir: projectDir,
          image: image,
          nodeId: nodeId!,
          prompt: prompt,
        ),
        VisualPromptTarget.stylePrefix ||
        VisualPromptTarget.negativePrompt => throw const VisualImageException(
          '这一行没有图片',
        ),
      };
      final saved = await saveProjectMerged(
        projects,
        projectId,
        (stored) => stored.copyWith(
          cast: redrawn.cast,
          assets: redrawn.assets,
          main: redrawn.main,
        ),
      );
      changes.markChanged(projectId);
      _notices[projectId] = doneLabel;
      return _pictureFile(saved, projectDir, target, characterId, nodeId);
    } catch (error, stack) {
      AppLog.instance.error(
        '重画画面失败（$projectId）',
        tag: 'visual.regen',
        error: error,
        stackTrace: stack,
      );
      _notices[projectId] = error.toString();
      return null;
    } finally {
      _finish(projectId);
    }
  }

  Future<void> _runBatch(
    _RunningJob job, {
    required String projectId,
    required Project project,
    required AiImageEndpoint image,
    required VisualPromptPlan plan,
    required String doneLabel,
  }) async {
    try {
      final projectDir = await _directoryFor(projectId);
      final next = await _pipeline().run(
        project: project,
        projectDir: projectDir,
        image: image,
        plan: plan,
        skipExisting: true,
        onProgress: (message, progress) =>
            _tick(projectId, job, message, progress),
      );
      await saveProjectMerged(
        projects,
        projectId,
        (stored) => stored.copyWith(
          cast: next.cast,
          assets: next.assets,
          main: next.main,
        ),
      );
      changes.markChanged(projectId);
      _notices[projectId] = doneLabel;
      AppLog.instance.info('画面图片已写入（$projectId）', tag: 'visual.images');
    } catch (error, stack) {
      AppLog.instance.error(
        '生成画面图片失败（$projectId）',
        tag: 'visual.images',
        error: error,
        stackTrace: stack,
      );
      _notices[projectId] = error.toString();
    } finally {
      _finish(projectId);
    }
  }

  _RunningJob? _begin(String projectId, String status) {
    if (_running.containsKey(projectId)) return null;
    final job = _RunningJob(status);
    _running[projectId] = job;
    _notify();
    return job;
  }

  Future<String> _directoryFor(String projectId) async {
    final dir = await projects.directoryFor(projectId);
    if (dir == null || dir.isEmpty) {
      throw const VisualImageException('找不到故事文件夹');
    }
    return dir;
  }

  void _tick(String projectId, _RunningJob job, String status, double? progress) {
    if (!identical(_running[projectId], job)) return;
    job.status = status;
    job.progress = progress;
    _notify();
  }

  void _finish(String projectId) {
    _running.remove(projectId);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static File? _pictureFile(
    Project project,
    String projectDir,
    VisualPromptTarget target,
    String? characterId,
    String? nodeId,
  ) {
    final assetId = switch (target) {
      VisualPromptTarget.portrait => project.castById(characterId!)?.avatarAssetId,
      VisualPromptTarget.scene =>
        project.main.nodeById(nodeId!)?.backgroundAssetId,
      VisualPromptTarget.stylePrefix || VisualPromptTarget.negativePrompt => null,
    };
    if (assetId == null) return null;
    return ProjectAssetFiles.tryFile(
      projectDir: projectDir,
      asset: project.assetById(assetId),
    );
  }
}

/// Mutable state of one run; [VisualImageJob] is the read-only view of it.
class _RunningJob {
  _RunningJob(this.status);

  String status;
  double? progress;
}
