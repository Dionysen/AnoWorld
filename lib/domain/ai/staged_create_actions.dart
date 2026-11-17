import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
/// Structured AI actions for UX path 3 (world → cast → short main).
class StagedCreateActions {
  StagedCreateActions({
    required AiTextClient textClient,
    this.mapper = const StageResultMapper(),
    this.validator = const ProjectValidator(),
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final StageResultMapper mapper;
  final ProjectValidator validator;
  final int maxFormatRetries;

  Future<Background> generateWorld({
    required AiPromptContext ctx,
    required String prompt,
  }) {
    final system = ctx.assembleSystem(taskSuffix: _worldSchema);
    return _completeMapped(
      ctx: ctx,
      system: system,
      user: '用户提示：\n${prompt.trim()}',
      map: mapper.backgroundFromRaw,
    );
  }

  Future<List<CastMember>> generateCast({
    required AiPromptContext ctx,
    required String prompt,
    required Background background,
  }) {
    final system = ctx.assembleSystem(
      worldInfoBefore: background.combinedText,
      taskSuffix: _castSchema,
    );
    return _completeMapped(
      ctx: ctx,
      system: system,
      user: '已有设定：\n${background.combinedText}\n\n用户提示：\n${prompt.trim()}',
      map: mapper.castFromRaw,
    );
  }

  Future<MainStory> generateMain({
    required AiPromptContext ctx,
    required String prompt,
    required Background background,
    required List<CastMember> cast,
  }) async {
    final castLines = cast
        .map((c) => '- ${c.name}：${c.summary}')
        .join('\n');
    final stub = Project(
      meta: ProjectMeta(
        id: 'probe',
        title: 'probe',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      background: background,
      cast: cast,
      main: const MainStory(
        summary: '',
        startNodeId: '',
        nodes: [],
        edges: [],
        beats: [],
      ),
    );
    final system = ctx.assembleSystem(
      project: stub,
      taskSuffix: _mainSchema,
    );
    final main = await _completeMapped(
      ctx: ctx,
      system: system,
      user: '已有设定：\n${background.combinedText}\n\n'
          '角色：\n$castLines\n\n用户提示：\n${prompt.trim()}',
      map: (raw) => mapper.mainFromRaw(raw, cast: cast),
    );

    final probe = stub.copyWith(main: main);
    final result = validator.validate(probe);
    if (result.hasErrors) {
      throw AiTextException('生成结果不完整，请重试');
    }
    return main;
  }

  Project applyWorld(Project project, Background background) {
    return project.copyWith(
      background: background,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  Project applyCast(Project project, List<CastMember> cast) {
    return project.copyWith(
      cast: cast,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  Project applyMain(Project project, MainStory main) {
    return project.copyWith(
      main: main,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<T> _completeMapped<T>({
    required AiPromptContext ctx,
    required String system,
    required String user,
    required T Function(String raw) map,
  }) async {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }

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
        return map(raw);
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

  static const String _worldSchema = '''
输出格式：
{"sections":[{"title":"世界观","body":"..."},{"title":"规则或禁忌","body":"..."}]}
根据用户一两句提示，写出 1～3 段简洁设定。只输出 JSON，不要 markdown，不要解释。''';

  static const String _castSchema = '''
输出格式：
{"cast":[{"name":"姓名","summary":"一句话","personality":"性格","speechStyle":"说话风格","exampleLines":["例句"]}]}
根据用户提示生成 2～4 个角色；姓名要短、好记。只输出 JSON，不要 markdown，不要解释。''';

  static const String _mainSchema = '''
输出格式（只出脉络骨架，不要对白）：
{"summary":"主线概括","stations":[{"title":"大站标题","synopsis":"本站必须达成的剧情目标","exits":[{"to":"下一站标题或end","kind":"default|branch","label":"可选标注"}]}],"edges":[{"from":"站标题","to":"站标题或end","kind":"default|branch","label":"可选"}]}
规则：
- 3～5 个 stations（大情节站）；synopsis 必填且短
- 用 exits 或 edges 表达顺序与分支；至少一处 branch 或两条不同结局（to 可为 end）
- 不要输出 lines / choices / 对白
- 结局站可用 ending:true，或 exits.to = "end"
- 只输出 JSON，不要 markdown，不要解释''';
}