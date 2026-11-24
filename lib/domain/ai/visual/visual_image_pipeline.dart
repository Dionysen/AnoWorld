import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/data/project/sprite_alpha.dart';
import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_asset.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/comfyui_client.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

typedef VisualProgress = void Function(String message, double? progress);

/// Runs Comfy generations and binds assets onto a [Project].
class VisualImagePipeline {
  VisualImagePipeline({
    ComfyUiClient? client,
  }) : _comfy = client ?? ComfyUiClient();

  final ComfyUiClient _comfy;

  Future<void> ensureReady(AiImageEndpoint image) async {
    if (image.kind != AiImageProviderKind.comfyui) {
      throw const VisualImageException('当前生图通道请选 ComfyUI');
    }
    if (!image.isConfigured) {
      throw const VisualImageException('请先在设置里填好生图服务地址');
    }
    await _comfy.ping(image.baseUrl);
  }

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
  }) async {
    final resolvedUpscale = upscale ?? image.upscale;
    final resolvedSteps = steps ?? image.steps;
    final portraitW = image.portraitWidth;
    final portraitH = image.portraitHeight;
    final sceneW = image.sceneWidth;
    final sceneH = image.sceneHeight;
    await ensureReady(image);

    var next = applyVisualTags(project, plan);
    final assets = List<ProjectAsset>.from(next.assets);
    void upsertAsset(ProjectAsset asset) {
      final i = assets.indexWhere((a) => a.id == asset.id);
      if (i >= 0) {
        assets[i] = asset;
      } else {
        assets.add(asset);
      }
    }

    final total = (generateAvatars ? plan.characters.length : 0) +
        (generateScenes ? plan.scenes.length : 0);
    var done = 0;

    if (generateAvatars) {
      final castOut = <CastMember>[];
      for (final row in plan.characters) {
        final member = next.castById(row.characterId);
        if (member == null) continue;
        if (skipExisting &&
            member.avatarAssetId != null &&
            member.avatarAssetId!.isNotEmpty) {
          castOut.add(member);
          done++;
          onProgress?.call('跳过已有立绘：${row.name}', _p(done, total));
          continue;
        }
        onProgress?.call('正在画立绘：${row.name}', _p(done, total));
        final raw = await _comfy.generatePng(
          baseUrl: image.baseUrl,
          workflow: ComfyWorkflowTemplates.portrait(
            prompt: row.portraitPrompt,
            negative: plan.negativePrompt,
            width: portraitW,
            height: portraitH,
            steps: resolvedSteps,
            upscale: resolvedUpscale,
            checkpoint: _checkpoint(image),
          ),
          clientId: 'anoworld-avatar-${row.characterId}',
        );
        onProgress?.call('去背透明：${row.name}', _p(done, total));
        final bytes = makeSpriteTransparentPng(raw);
        final assetId = 'avatar_${row.characterId}';
        final asset = await ProjectAssetFiles.writePng(
          projectDir: projectDir,
          assetId: assetId,
          kind: ProjectAssetKind.avatar,
          relativePath: ProjectAssetFiles.avatarRelativePath(row.characterId),
          bytes: bytes,
        );
        upsertAsset(asset);
        castOut.add(
          member.copyWith(
            visualTags: row.visualTags,
            portraitPrompt: ComfyWorkflowTemplates.enforcePortraitFraming(
              row.portraitPrompt,
            ),
            avatarAssetId: assetId,
          ),
        );
        done++;
        onProgress?.call('立绘完成：${row.name}', _p(done, total));
      }
      // Keep cast members not in plan.
      final seen = castOut.map((c) => c.id).toSet();
      for (final m in next.cast) {
        if (!seen.contains(m.id)) castOut.add(m);
      }
      next = next.copyWith(cast: castOut, assets: assets);
    }

    if (generateScenes) {
      final nodesOut = <StoryNode>[];
      final beatsOut = List<Beat>.from(next.main.beats);
      for (final row in plan.scenes) {
        final node = next.main.nodeById(row.nodeId);
        if (node == null) continue;
        if (skipExisting &&
            node.backgroundAssetId != null &&
            node.backgroundAssetId!.isNotEmpty) {
          nodesOut.add(node);
          done++;
          onProgress?.call('跳过已有场景：${row.title}', _p(done, total));
          continue;
        }
        onProgress?.call('正在画场景：${row.title}', _p(done, total));
        final bytes = await _comfy.generatePng(
          baseUrl: image.baseUrl,
          workflow: ComfyWorkflowTemplates.scene(
            prompt: row.scenePrompt,
            negative: plan.negativePrompt,
            width: sceneW,
            height: sceneH,
            steps: resolvedSteps,
            upscale: resolvedUpscale,
            checkpoint: _checkpoint(image),
          ),
          clientId: 'anoworld-scene-${row.nodeId}',
        );
        final assetId = 'bg_${row.nodeId}';
        final asset = await ProjectAssetFiles.writePng(
          projectDir: projectDir,
          assetId: assetId,
          kind: ProjectAssetKind.background,
          relativePath: ProjectAssetFiles.backgroundRelativePath(row.nodeId),
          bytes: bytes,
        );
        upsertAsset(asset);
        final updatedNode = node.copyWith(
          imagePrompt: row.scenePrompt,
          backgroundAssetId: assetId,
        );
        nodesOut.add(updatedNode);

        // Mirror onto first beat scene when the node already has beats.
        if (node.beatIds.isNotEmpty) {
          final firstId = node.beatIds.first;
          final bi = beatsOut.indexWhere((b) => b.id == firstId);
          if (bi >= 0) {
            final beat = beatsOut[bi];
            beatsOut[bi] = beat.copyWith(
              scene: beat.scene.copyWith(backgroundAssetId: assetId),
            );
          }
        }
        done++;
        onProgress?.call('场景完成：${row.title}', _p(done, total));
      }
      final seen = nodesOut.map((n) => n.id).toSet();
      for (final n in next.main.nodes) {
        if (!seen.contains(n.id)) nodesOut.add(n);
      }
      // Preserve node order from main.
      final ordered = next.main.nodes
          .map((n) => nodesOut.firstWhere((x) => x.id == n.id, orElse: () => n))
          .toList(growable: false);
      next = next.copyWith(
        assets: assets,
        main: next.main.copyWith(nodes: ordered, beats: beatsOut),
      );
    }

    return next.copyWith(
      meta: next.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  /// Regenerates one cast portrait (overwrites existing avatar asset).
  Future<Project> regenerateAvatar({
    required Project project,
    required String projectDir,
    required AiImageEndpoint image,
    required String characterId,
    String? prompt,
    String? negative,
  }) async {
    await ensureReady(image);
    final member = project.castById(characterId);
    if (member == null) {
      throw const VisualImageException('找不到这个角色');
    }
    final resolvedPrompt = ComfyWorkflowTemplates.enforcePortraitFraming(
      (prompt ?? defaultPortraitPrompt(member)).trim(),
    );
    if (resolvedPrompt.isEmpty) {
      throw const VisualImageException('还没有立绘提示词，先去「画面」写好');
    }
    AppLog.instance.info(
      '重绘立绘 ${member.name}',
      tag: 'visual.regen',
    );
    final raw = await _comfy.generatePng(
      baseUrl: image.baseUrl,
      workflow: ComfyWorkflowTemplates.portrait(
        prompt: resolvedPrompt,
        negative: negative ?? ComfyWorkflowTemplates.defaultNegative,
        width: image.portraitWidth,
        height: image.portraitHeight,
        steps: image.steps,
        upscale: image.upscale,
        checkpoint: _checkpoint(image),
      ),
      clientId: 'anoworld-avatar-regen-$characterId',
    );
    final bytes = makeSpriteTransparentPng(raw);
    final assetId = 'avatar_$characterId';
    final asset = await ProjectAssetFiles.writePng(
      projectDir: projectDir,
      assetId: assetId,
      kind: ProjectAssetKind.avatar,
      relativePath: ProjectAssetFiles.avatarRelativePath(characterId),
      bytes: bytes,
    );
    final assets = List<ProjectAsset>.from(project.assets);
    final ai = assets.indexWhere((a) => a.id == assetId);
    if (ai >= 0) {
      assets[ai] = asset;
    } else {
      assets.add(asset);
    }
    final cast = project.cast
        .map(
          (m) => m.id == characterId
              ? m.copyWith(avatarAssetId: assetId)
              : m,
        )
        .toList(growable: false);
    AppLog.instance.info('立绘已更新 ${member.name}', tag: 'visual.regen');
    return project.copyWith(
      cast: cast,
      assets: assets,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  /// Regenerates one node background (overwrites existing scene asset).
  Future<Project> regenerateScene({
    required Project project,
    required String projectDir,
    required AiImageEndpoint image,
    required String nodeId,
    String? prompt,
    String? negative,
  }) async {
    await ensureReady(image);
    final node = project.main.nodeById(nodeId);
    if (node == null) {
      throw const VisualImageException('找不到这一站');
    }
    final resolvedPrompt = (prompt ?? defaultScenePrompt(node)).trim();
    if (resolvedPrompt.isEmpty) {
      throw const VisualImageException('还没有场景提示词，先去「画面」写好');
    }
    AppLog.instance.info(
      '重绘场景 ${node.title}',
      tag: 'visual.regen',
    );
    final bytes = await _comfy.generatePng(
      baseUrl: image.baseUrl,
      workflow: ComfyWorkflowTemplates.scene(
        prompt: resolvedPrompt,
        negative: negative ?? ComfyWorkflowTemplates.defaultNegative,
        width: image.sceneWidth,
        height: image.sceneHeight,
        steps: image.steps,
        upscale: image.upscale,
        checkpoint: _checkpoint(image),
      ),
      clientId: 'anoworld-scene-regen-$nodeId',
    );
    final assetId = 'bg_$nodeId';
    final asset = await ProjectAssetFiles.writePng(
      projectDir: projectDir,
      assetId: assetId,
      kind: ProjectAssetKind.background,
      relativePath: ProjectAssetFiles.backgroundRelativePath(nodeId),
      bytes: bytes,
    );
    final assets = List<ProjectAsset>.from(project.assets);
    final ai = assets.indexWhere((a) => a.id == assetId);
    if (ai >= 0) {
      assets[ai] = asset;
    } else {
      assets.add(asset);
    }
    final beatsOut = List<Beat>.from(project.main.beats);
    if (node.beatIds.isNotEmpty) {
      final firstId = node.beatIds.first;
      final bi = beatsOut.indexWhere((b) => b.id == firstId);
      if (bi >= 0) {
        final beat = beatsOut[bi];
        beatsOut[bi] = beat.copyWith(
          scene: beat.scene.copyWith(backgroundAssetId: assetId),
        );
      }
    }
    final nodes = project.main.nodes
        .map(
          (n) => n.id == nodeId
              ? n.copyWith(
                  imagePrompt: resolvedPrompt,
                  backgroundAssetId: assetId,
                )
              : n,
        )
        .toList(growable: false);
    AppLog.instance.info('场景已更新 ${node.title}', tag: 'visual.regen');
    return project.copyWith(
      assets: assets,
      main: project.main.copyWith(nodes: nodes, beats: beatsOut),
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  /// Deletes one cast portrait file and clears links in the story.
  Future<Project> clearAvatar({
    required Project project,
    required String projectDir,
    required String characterId,
  }) async {
    final member = project.castById(characterId);
    if (member == null) {
      throw const VisualImageException('找不到这个角色');
    }
    final assetId = member.avatarAssetId;
    if (assetId == null) {
      throw const VisualImageException('这个角色还没有立绘');
    }
    final asset = project.assetById(assetId);
    if (asset != null) {
      await ProjectAssetFiles.deleteIfPresent(projectDir: projectDir, asset: asset);
    }
    final assets = [
      for (final a in project.assets)
        if (a.id != assetId) a,
    ];
    final cast = project.cast
        .map(
          (m) => m.id == characterId
              ? m.copyWith(clearAvatarAssetId: true)
              : m,
        )
        .toList(growable: false);
    AppLog.instance.info('已删除立绘 ${member.name}', tag: 'visual.delete');
    return project.copyWith(
      cast: cast,
      assets: assets,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  /// Deletes one node background file and clears links in the story.
  Future<Project> clearScene({
    required Project project,
    required String projectDir,
    required String nodeId,
  }) async {
    final node = project.main.nodeById(nodeId);
    if (node == null) {
      throw const VisualImageException('找不到这一站');
    }
    final assetId = node.backgroundAssetId;
    if (assetId == null) {
      throw const VisualImageException('这一站还没有场景图');
    }
    final asset = project.assetById(assetId);
    if (asset != null) {
      await ProjectAssetFiles.deleteIfPresent(projectDir: projectDir, asset: asset);
    }
    final assets = [
      for (final a in project.assets)
        if (a.id != assetId) a,
    ];
    final beatsOut = List<Beat>.from(project.main.beats);
    if (node.beatIds.isNotEmpty) {
      final firstId = node.beatIds.first;
      final bi = beatsOut.indexWhere((b) => b.id == firstId);
      if (bi >= 0) {
        final beat = beatsOut[bi];
        beatsOut[bi] = beat.copyWith(
          scene: beat.scene.copyWith(clearBackgroundAssetId: true),
        );
      }
    }
    final nodes = project.main.nodes
        .map(
          (n) => n.id == nodeId
              ? n.copyWith(clearBackgroundAssetId: true)
              : n,
        )
        .toList(growable: false);
    AppLog.instance.info('已删除场景 ${node.title}', tag: 'visual.delete');
    return project.copyWith(
      assets: assets,
      main: project.main.copyWith(nodes: nodes, beats: beatsOut),
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  /// Default portrait prompt from the kept prompt, else locked tags / facing.
  static String defaultPortraitPrompt(CastMember member) {
    final stored = member.portraitPrompt.trim();
    if (stored.isNotEmpty) {
      return ComfyWorkflowTemplates.enforcePortraitFraming(stored);
    }
    final tags = member.visualTags.trim();
    if (tags.isEmpty) return '';
    return '${ComfyWorkflowTemplates.defaultStylePrefix}, $tags, '
        '${ComfyWorkflowTemplates.portraitCompositionFor(member.facing)}';
  }

  /// Prefer stored [StoryNode.imagePrompt]; else a short scenery fallback.
  static String defaultScenePrompt(StoryNode node) {
    final stored = node.imagePrompt?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final goal = node.synopsis?.trim() ?? '';
    final bits = <String>[
      ComfyWorkflowTemplates.defaultStylePrefix,
      'anime scenery',
      node.title.trim(),
      if (goal.isNotEmpty) goal,
    ];
    return bits.where((s) => s.isNotEmpty).join(', ');
  }

  static Project applyVisualTags(Project project, VisualPromptPlan plan) {
    final byId = <String, CharacterVisualPrompt>{
      for (final c in plan.characters) c.characterId: c,
    };
    final cast = project.cast.map((m) {
      final row = byId[m.id];
      if (row == null) return m;
      return m.copyWith(
        visualTags: row.visualTags,
        portraitPrompt: ComfyWorkflowTemplates.enforcePortraitFraming(
          row.portraitPrompt,
        ),
        facing: row.facing,
      );
    }).toList(growable: false);
    final sceneById = <String, SceneVisualPrompt>{
      for (final s in plan.scenes) s.nodeId: s,
    };
    final nodes = project.main.nodes.map((n) {
      final row = sceneById[n.id];
      if (row == null) return n;
      return n.copyWith(imagePrompt: row.scenePrompt);
    }).toList(growable: false);
    return project.copyWith(
      cast: cast,
      main: project.main.copyWith(nodes: nodes),
    );
  }

  static double? _p(int done, int total) {
    if (total <= 0) return null;
    return done / total;
  }

  static String _checkpoint(AiImageEndpoint image) {
    final named = image.model.trim();
    if (named.isNotEmpty) return named;
    return ComfyWorkflowTemplates.defaultCheckpoint;
  }
}

class VisualImageException implements Exception {
  const VisualImageException(this.message);
  final String message;

  @override
  String toString() => message;
}
