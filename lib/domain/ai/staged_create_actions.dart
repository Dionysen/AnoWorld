import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_prompt_profiles.dart';
import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/validation/project_validator.dart';

/// Structured AI actions for UX path 3 (world → cast → short main).
class StagedCreateActions {
  StagedCreateActions({
    required AiTextClient textClient,
    this.mapper = const StageResultMapper(),
    this.validator = const ProjectValidator(),
    this.maxFormatRetries = 1,
    this.minGraphStations = AiSettings.defaultMinGraphStations,
  }) : _text = textClient;

  final AiTextClient _text;
  final StageResultMapper mapper;
  final ProjectValidator validator;
  final int maxFormatRetries;
  final int minGraphStations;

  Future<WorldBook> generateWorld({
    required AiPromptContext ctx,
    required String prompt,
  }) {
    final system = ctx.assembleSystem(taskSuffix: _worldSchema);
    return _completeMapped(
      ctx: ctx,
      system: system,
      user: '用户提示：\n${prompt.trim()}',
      map: mapper.worldBookFromRaw,
    );
  }

  Future<List<CastMember>> generateCast({
    required AiPromptContext ctx,
    required String prompt,
    required WorldBook worldBook,
  }) {
    final system = ctx.assembleSystem(
      worldInfoBefore: worldBook.combinedText,
      taskSuffix: _castSchema,
    );
    return _completeMapped(
      ctx: ctx,
      system: system,
      user: '已有设定：\n${worldBook.combinedText}\n\n用户提示：\n${prompt.trim()}',
      map: mapper.castFromRaw,
    );
  }

  Future<MainStory> generateMain({
    required AiPromptContext ctx,
    required String prompt,
    required WorldBook worldBook,
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
      worldBook: worldBook,
      cast: cast,
      main: const MainStory(
        summary: '',
        startNodeId: '',
        nodes: [],
        edges: [],
        beats: [],
      ),
    );
    final floor = AiSettings.clampMinGraphStations(minGraphStations);
    final system = ctx.assembleSystem(
      project: stub,
      taskSuffix: _mainSchema(floor),
    );
    final main = await _completeMapped(
      ctx: ctx,
      system: system,
      user: '已有设定：\n${worldBook.combinedText}\n\n'
          '角色：\n$castLines\n\n用户提示：\n${prompt.trim()}',
      map: (raw) => mapper.mainFromRaw(
        raw,
        cast: cast,
        enforceMinStations: true,
        minStations: floor,
      ),
    );

    final probe = stub.copyWith(main: main);
    final result = validator.validate(probe);
    if (result.hasErrors) {
      throw AiTextException('生成结果不完整，请重试');
    }
    return main;
  }

  Project applyWorldBook(Project project, WorldBook worldBook) {
    return project.copyWith(
      worldBook: worldBook,
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

  static String _mainSchema(int minStations) => '输出格式：\n'
      '${CreatePromptProfiles.skeletonFormat}\n'
      '规则：\n'
      '${CreatePromptProfiles.skeletonRules(minStations)}\n'
      '只输出 JSON，不要 markdown，不要解释。';
}