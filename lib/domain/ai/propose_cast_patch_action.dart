import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_prompt_profiles.dart';
import 'package:anoworld/domain/main/apply_cast_patch.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

class ProposeCastPatchAction {
  ProposeCastPatchAction({
    required AiTextClient textClient,
    this.applier = const ApplyCastPatch(),
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final ApplyCastPatch applier;
  final int maxFormatRetries;

  Future<CastPatchProposal> propose({
    required AiPromptContext ctx,
    required Project project,
    required String prompt,
  }) async {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw AiTextException('先说想改哪个角色');
    }

    final system = ctx.assembleSystem(
      project: project,
      taskSuffix: CreatePromptProfiles.castPatchTaskSuffix,
    );
    final buffer = StringBuffer('现有角色：\n');
    if (project.cast.isEmpty) {
      buffer.writeln('(空)');
    } else {
      for (final c in project.cast) {
        final tag = c.isProtagonist ? '|主角' : '';
        buffer.writeln('- ${c.id}|${c.name}$tag');
        if (c.summary.isNotEmpty) buffer.writeln('简介：${c.summary}');
        if (c.personality.isNotEmpty) buffer.writeln('性格：${c.personality}');
        if (c.speechStyle.isNotEmpty) buffer.writeln('口吻：${c.speechStyle}');
        buffer.writeln();
      }
    }
    buffer.writeln('用户想改：\n$trimmed');
    final user = buffer.toString();

    String? lastError;
    var attemptUser = user;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      final raw = (await _text.complete(
        endpoint: endpoint,
        system: system,
        user: attemptUser,
        generation: ctx.generation,
      ))
          .content;
      try {
        final ops = _parseOps(raw);
        if (ops.isEmpty) {
          throw AiTextException('没有可应用的改动');
        }
        final next = applier.apply(project.cast, ops);
        return CastPatchProposal(ops: ops, cast: next);
      } on ApplyCastPatchException catch (error) {
        lastError = error.message;
      } on AiTextException catch (error) {
        lastError = error.message;
      } catch (error) {
        lastError = error.toString();
      }
      if (attempt >= maxFormatRetries) break;
      attemptUser =
          '$user\n\n上次无法使用：$lastError\n请只输出合法 ops JSON。';
    }
    throw AiTextException(lastError ?? '改动无法识别，请重试');
  }

  static List<Map<String, dynamic>> _parseOps(String raw) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw AiTextException('不是有效 JSON');
    }
    final list = decoded['ops'];
    if (list is! List || list.isEmpty) {
      throw AiTextException('缺少 ops');
    }
    return [
      for (final item in list)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}

class CastPatchProposal {
  const CastPatchProposal({
    required this.ops,
    required this.cast,
  });

  final List<Map<String, dynamic>> ops;
  final List<CastMember> cast;
}
