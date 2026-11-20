import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_prompt_profiles.dart';
import 'package:anoworld/domain/main/apply_main_graph_patch.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

/// Asks the model for incremental graph ops and validates by dry-applying.
class ProposeMainGraphPatchAction {
  ProposeMainGraphPatchAction({
    required AiTextClient textClient,
    this.applier = const ApplyMainGraphPatch(),
    this.validator = const ProjectValidator(),
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final ApplyMainGraphPatch applier;
  final ProjectValidator validator;
  final int maxFormatRetries;

  Future<MainGraphPatchProposal> propose({
    required AiPromptContext ctx,
    required Project project,
    required String prompt,
    PlotElementCatalog? plotCatalog,
  }) async {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw AiTextException('先说想改哪里');
    }
    if (!project.main.hasAuthoredNodes) {
      throw AiTextException('还没有情节图，先整图生成');
    }

    final system = ctx.assembleSystem(
      project: project,
      plotCatalog: plotCatalog,
      taskSuffix: CreatePromptProfiles.mainGraphPatchTaskSuffix,
    );
    final user = '''现有情节骨架：
${MainGraphDocument.encodeSkeletonJson(project.main, includeLayout: false)}

用户想改：
$trimmed''';

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
        final next = applier.apply(project.main, ops);
        final probe = validator.validate(project.copyWith(main: next));
        if (probe.hasErrors) {
          throw AiTextException('改完后情节不完整');
        }
        return MainGraphPatchProposal(ops: ops, main: next);
      } on ApplyMainGraphPatchException catch (error) {
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
    final ops = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is Map) {
        ops.add(Map<String, dynamic>.from(item));
      }
    }
    return ops;
  }
}

class MainGraphPatchProposal {
  const MainGraphPatchProposal({
    required this.ops,
    required this.main,
  });

  final List<Map<String, dynamic>> ops;
  final MainStory main;
}
