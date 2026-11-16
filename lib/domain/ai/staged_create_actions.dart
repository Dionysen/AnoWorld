import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/preset.dart';
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
  }) : _text = textClient;

  final AiTextClient _text;
  final StageResultMapper mapper;
  final ProjectValidator validator;
  final int maxFormatRetries;

  Future<Background> generateWorld({
    required AiTextEndpoint endpoint,
    required Preset preset,
    required String prompt,
  }) {
    return _completeMapped(
      endpoint: endpoint,
      system: _systemPreamble(preset) + _worldSchema,
      user: '用户提示：\n${prompt.trim()}',
      map: mapper.backgroundFromRaw,
    );
  }

  Future<List<CastMember>> generateCast({
    required AiTextEndpoint endpoint,
    required Preset preset,
    required String prompt,
    required Background background,
  }) {
    return _completeMapped(
      endpoint: endpoint,
      system: _systemPreamble(preset) + _castSchema,
      user: '已有设定：\n${background.combinedText}\n\n用户提示：\n${prompt.trim()}',
      map: mapper.castFromRaw,
    );
  }

  Future<MainStory> generateMain({
    required AiTextEndpoint endpoint,
    required Preset preset,
    required String prompt,
    required Background background,
    required List<CastMember> cast,
  }) async {
    final castLines = cast
        .map((c) => '- ${c.name}：${c.summary}')
        .join('\n');
    final main = await _completeMapped(
      endpoint: endpoint,
      system: _systemPreamble(preset) + _mainSchema,
      user: '已有设定：\n${background.combinedText}\n\n'
          '角色：\n$castLines\n\n用户提示：\n${prompt.trim()}',
      map: (raw) => mapper.mainFromRaw(raw, cast: cast),
    );

    final probe = Project(
      meta: ProjectMeta(
        id: 'probe',
        title: 'probe',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      presets: <Preset>[preset],
      activePresetId: preset.id,
      background: background,
      cast: cast,
      main: main,
    );
    final result = validator.validate(probe);
    if (result.hasErrors) {
      throw AiTextException('生成结果不完整，请重试');
    }
    return main;
  }

  /// Merge helpers: rewrite only the targeted layer.
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
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    required T Function(String raw) map,
  }) async {
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }

    String? lastError;
    var attemptUser = user;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      final raw = await _text.complete(
        endpoint: endpoint,
        system: system,
        user: attemptUser,
      );
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

  static String _systemPreamble(Preset preset) {
    final bans = preset.outputBans.isEmpty
        ? ''
        : '禁止：${preset.outputBans.join('；')}\n';
    final prefs = preset.outputPreferences.isEmpty
        ? ''
        : '偏好：${preset.outputPreferences.join('；')}\n';
    return '你是视觉小说创作助手。只输出 JSON，不要 markdown，不要解释。\n'
        '文风：${preset.styleNotes}\n'
        '$bans$prefs';
  }

  static const String _worldSchema = '''
输出格式：
{"sections":[{"title":"世界观","body":"..."},{"title":"规则或禁忌","body":"..."}]}
根据用户一两句提示，写出 1～3 段简洁设定。''';

  static const String _castSchema = '''
输出格式：
{"cast":[{"name":"姓名","summary":"一句话","personality":"性格","speechStyle":"说话风格","exampleLines":["例句"]}]}
根据用户提示生成 2～4 个角色；姓名要短、好记。''';

  static const String _mainSchema = '''
输出格式：
{"summary":"主线概括","scenes":[{"title":"场景标题","synopsis":"本场目标","location":"地点","speakers":["角色名"],"lines":[{"speaker":"角色名或旁白","text":"对白"}],"choices":[{"text":"选项","end":true},{"text":"选项","stay":true}]}]}
规则：
- 恰好 2 个 scenes（短开场）
- 每场若干短对白；speaker 必须是已有角色名或「旁白」
- 第一场不要 choices（播完进入下一场）
- 第二场必须有 2～3 个 choices；至少一项 end:true，可用 stay:true 表示留在本场''';
}
