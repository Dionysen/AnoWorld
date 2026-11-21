import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_asset.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/comfyui_client.dart';

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
    bool upscale = true,
    bool skipExisting = true,
    VisualProgress? onProgress,
  }) async {
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
        final bytes = await _comfy.generatePng(
          baseUrl: image.baseUrl,
          workflow: ComfyWorkflowTemplates.portrait(
            prompt: row.portraitPrompt,
            negative: plan.negativePrompt,
            upscale: upscale,
          ),
          clientId: 'anoworld-avatar-${row.characterId}',
        );
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
            upscale: upscale,
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

  static Project applyVisualTags(Project project, VisualPromptPlan plan) {
    final byId = <String, CharacterVisualPrompt>{
      for (final c in plan.characters) c.characterId: c,
    };
    final cast = project.cast.map((m) {
      final row = byId[m.id];
      if (row == null) return m;
      return m.copyWith(visualTags: row.visualTags);
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
}

class VisualImageException implements Exception {
  const VisualImageException(this.message);
  final String message;

  @override
  String toString() => message;
}
