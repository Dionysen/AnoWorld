import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_prompt_profiles.dart';
import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/domain/validation/project_validator.dart';

/// Generates a plot skeleton (stations + edges) from a story's world book and
/// the user's prompt. Beats stay empty: play fills them per interval.
class GenerateMainGraphAction {
  GenerateMainGraphAction({
    required AiTextClient textClient,
    this.mapper = const StageResultMapper(),
    this.validator = const ProjectValidator(),
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final StageResultMapper mapper;
  final ProjectValidator validator;
  final int maxFormatRetries;

  Future<MainStory> generate({
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
      throw AiTextException('先说一句想要的走向');
    }

    final system = ctx.assembleSystem(
      project: project,
      plotCatalog: plotCatalog,
      taskSuffix: CreatePromptProfiles.mainGraphTaskSuffix,
    );
    final user = _buildUserMessage(project, trimmed);

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
        final main = mapper.mainFromRaw(raw, cast: project.cast);
        final probe = validator.validate(project.copyWith(main: main));
        if (probe.hasErrors) {
          throw const StageMapException('生成的情节不完整');
        }
        return main;
      } on StageMapException catch (error) {
        lastError = error.message;
        if (attempt >= maxFormatRetries) break;
        attemptUser = '$user\n\n'
            '上次输出无法解析：$lastError\n'
            '请只输出合法 JSON，不要用 markdown 代码块，不要附加说明。';
      }
    }
    throw AiTextException(lastError ?? '生成结果无法识别，请重试');
  }

  String _buildUserMessage(Project project, String prompt) {
    final buffer = StringBuffer()..writeln('故事名：${project.meta.title}');
    if (project.cast.isNotEmpty) {
      buffer.writeln('\n角色：');
      for (final member in project.cast) {
        final name = member.name.trim();
        final summary = member.summary.trim();
        buffer.writeln(summary.isEmpty ? '- $name' : '- $name：$summary');
      }
    }
    if (project.main.hasAuthoredNodes) {
      buffer.writeln('\n现有情节（可改写，保持人物与设定一致）：');
      buffer.writeln(
        MainGraphDocument.encodeSkeletonJson(
          project.main,
          includeLayout: false,
        ),
      );
    }
    buffer.writeln('\n用户想要的走向：');
    buffer.writeln(prompt);
    return buffer.toString();
  }
}
