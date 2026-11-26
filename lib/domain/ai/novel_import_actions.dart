import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/novel_import_draft.dart';
import 'package:anoworld/domain/ai/novel_text_chunker.dart';
import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/ai/staged_create_actions.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

enum NovelImportStep { outline, world, cast, main }

/// Path 2: pasted / imported novel → outline → world → cast → main skeleton.
class NovelImportActions {
  NovelImportActions({
    required AiTextClient textClient,
    this.mapper = const StageResultMapper(),
    this.validator = const ProjectValidator(),
    this.chunker = const NovelTextChunker(),
    this.maxFormatRetries = 1,
    this.minGraphStations = AiSettings.defaultMinGraphStations,
    this.maxOutlineChunks = 12,
  }) : _text = textClient,
       _staged = StagedCreateActions(
         textClient: textClient,
         mapper: mapper,
         validator: validator,
         maxFormatRetries: maxFormatRetries,
         minGraphStations: minGraphStations,
       );

  final AiTextClient _text;
  final StageResultMapper mapper;
  final ProjectValidator validator;
  final NovelTextChunker chunker;
  final int maxFormatRetries;
  final int minGraphStations;
  final int maxOutlineChunks;
  final StagedCreateActions _staged;

  static const _logTag = 'novel.import';

  /// Runs the full pipeline; returns a draft ready for review (not yet saved).
  Future<NovelImportDraft> runPipeline({
    required AiPromptContext ctx,
    required String sourceText,
    String note = '',
    String? preferredTitle,
    void Function(NovelImportStep step)? onProgress,
  }) async {
    final prepared = chunker.prepare(sourceText);
    final scope = prepared.scope;
    if (scope.text.isEmpty) {
      throw AiTextException('请先粘贴或导入一段正文');
    }

    AppLog.instance.info(
      '开始导入：${scope.usedChars}/${scope.totalChars} 字'
      '${scope.truncated ? '（已截断）' : ''}',
      tag: _logTag,
    );
    if (scope.truncated) {
      AppLog.instance.warning(
        '正文超长，只用前 ${scope.usedChars} 字',
        tag: _logTag,
      );
    }

    var draft = NovelImportDraft(
      title: preferredTitle?.trim() ?? '',
      note: note.trim(),
      sourceRange: NovelSourceRange(
        usedChars: scope.usedChars,
        totalChars: scope.totalChars,
        truncated: scope.truncated,
      ),
    );

    final chunks = prepared.chunks;
    final outlineChunks = chunks.length <= maxOutlineChunks
        ? chunks
        : chunks.sublist(0, maxOutlineChunks);

    onProgress?.call(NovelImportStep.outline);
    final outline = await buildOutline(
      ctx: ctx,
      chunks: outlineChunks,
      note: draft.note,
    );
    draft = draft.copyWith(
      outline: outline,
      title: draft.title.isNotEmpty
          ? draft.title
          : (outline.title.trim().isEmpty ? draft.title : outline.title.trim()),
    );
    AppLog.instance.info('大纲完成：${outline.title}', tag: _logTag);

    final samples = outlineChunks.take(2).toList(growable: false);

    onProgress?.call(NovelImportStep.world);
    final worldBook = await buildWorld(
      ctx: ctx,
      outline: outline,
      note: draft.note,
      samples: samples,
    );
    draft = draft.copyWith(worldBook: worldBook);
    AppLog.instance.info(
      '设定完成：${worldBook.entries.length} 条',
      tag: _logTag,
    );

    onProgress?.call(NovelImportStep.cast);
    final cast = await buildCast(
      ctx: ctx,
      outline: outline,
      worldBook: worldBook,
      note: draft.note,
      samples: samples,
    );
    draft = draft.copyWith(cast: cast);
    AppLog.instance.info('角色完成：${cast.length} 人', tag: _logTag);

    onProgress?.call(NovelImportStep.main);
    final main = await buildMain(
      ctx: ctx,
      outline: outline,
      worldBook: worldBook,
      cast: cast,
      note: draft.note,
    );
    draft = draft.copyWith(main: main);
    AppLog.instance.info(
      '情节完成：${main.nodes.length} 站',
      tag: _logTag,
    );

    return draft;
  }

  Future<NovelOutline> buildOutline({
    required AiPromptContext ctx,
    required List<String> chunks,
    String note = '',
  }) async {
    if (chunks.isEmpty) {
      throw AiTextException('正文为空，无法提炼大纲');
    }

    final partials = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final system = ctx.assembleSystem(taskSuffix: _chunkSummarySchema);
      final user = StringBuffer()
        ..writeln('这是长文的第 ${i + 1}/${chunks.length} 段，请提炼本段要点。');
      if (note.trim().isNotEmpty) {
        user
          ..writeln()
          ..writeln('用户补充：')
          ..writeln(note.trim());
      }
      user
        ..writeln()
        ..writeln('正文：')
        ..writeln(chunks[i]);
      final raw = await _completeMapped(
        ctx: ctx,
        system: system,
        user: user.toString(),
        map: (s) => s,
      );
      partials.add(_outlinePartialLine(raw));
    }

    final system = ctx.assembleSystem(taskSuffix: _outlineReduceSchema);
    final user = StringBuffer()
      ..writeln('下面是各段要点，请合并成全书/本段大纲 JSON。');
    if (note.trim().isNotEmpty) {
      user
        ..writeln()
        ..writeln('用户补充：')
        ..writeln(note.trim());
    }
    user
      ..writeln()
      ..writeln('各段要点：');
    for (var i = 0; i < partials.length; i++) {
      user.writeln('${i + 1}. ${partials[i]}');
    }

    return _completeMapped(
      ctx: ctx,
      system: system,
      user: user.toString(),
      map: _outlineFromRaw,
    );
  }

  Future<WorldBook> buildWorld({
    required AiPromptContext ctx,
    required NovelOutline outline,
    String note = '',
    List<String> samples = const [],
  }) {
    final system = ctx.assembleSystem(taskSuffix: _worldSchema);
    final user = _contextUser(
      heading: '根据大纲与抽样正文，写出 1～3 段设定。',
      outline: outline,
      note: note,
      samples: samples,
    );
    return _completeMapped(
      ctx: ctx,
      system: system,
      user: user,
      map: mapper.worldBookFromRaw,
    );
  }

  Future<List<CastMember>> buildCast({
    required AiPromptContext ctx,
    required NovelOutline outline,
    required WorldBook worldBook,
    String note = '',
    List<String> samples = const [],
  }) {
    final system = ctx.assembleSystem(
      worldInfoBefore: worldBook.combinedText,
      taskSuffix: _castSchema,
    );
    final user = StringBuffer()
      ..writeln('根据大纲、设定与抽样正文，列出主要角色。')
      ..writeln()
      ..writeln('已有设定：')
      ..writeln(worldBook.combinedText)
      ..writeln()
      ..write(_contextUser(
        heading: '',
        outline: outline,
        note: note,
        samples: samples,
      ));
    return _completeMapped(
      ctx: ctx,
      system: system,
      user: user.toString().trim(),
      map: mapper.castFromRaw,
    );
  }

  Future<MainStory> buildMain({
    required AiPromptContext ctx,
    required NovelOutline outline,
    required WorldBook worldBook,
    required List<CastMember> cast,
    String note = '',
  }) {
    final prompt = StringBuffer()
      ..writeln('根据大纲与已有设定、角色，生成可玩的情节骨架。')
      ..writeln('不要输出对白；原文无分支时补少量合理岔路，并保留按原文继续的主线。')
      ..writeln()
      ..writeln(outline.promptBlock);
    if (note.trim().isNotEmpty) {
      prompt
        ..writeln()
        ..writeln('用户补充：')
        ..writeln(note.trim());
    }
    return _staged.generateMain(
      ctx: _withJsonObject(ctx),
      prompt: prompt.toString().trim(),
      worldBook: worldBook,
      cast: cast,
    );
  }

  /// Creates a project and writes the reviewed draft.
  Future<Project> commit({
    required ProjectRepository projects,
    required NovelImportDraft draft,
  }) async {
    final title = draft.title.trim().isEmpty
        ? (draft.outline.title.trim().isEmpty
            ? '未命名故事'
            : draft.outline.title.trim())
        : draft.title.trim();

    AppLog.instance.info('写入故事：$title', tag: _logTag);
    final created = await projects.create(title: title);
    var next = _staged.applyWorldBook(created, draft.worldBook);
    next = _staged.applyCast(next, draft.cast);
    next = _staged.applyMain(next, draft.main);
    next = next.copyWith(
      meta: next.meta.copyWith(title: title, updatedAt: DateTime.now().toUtc()),
    );

    final result = validator.validate(next);
    if (result.hasErrors) {
      AppLog.instance.warning(
        '校验未过：${result.errors.map((e) => e.message).join('；')}',
        tag: _logTag,
      );
      throw AiTextException('生成结果不完整，请重试或改后再写入');
    }

    await projects.save(next);
    AppLog.instance.info('写入完成：${next.meta.id}', tag: _logTag);
    return next;
  }

  AiPromptContext _withJsonObject(AiPromptContext ctx) {
    return AiPromptContext(
      endpoint: ctx.endpoint,
      generation: ctx.generation.copyWith(jsonObject: true),
      promptManager: ctx.promptManager,
      persona: ctx.persona,
    );
  }

  Future<T> _completeMapped<T>({
    required AiPromptContext ctx,
    required String system,
    required String user,
    required T Function(String raw) map,
  }) async {
    final jsonCtx = _withJsonObject(ctx);
    final endpoint = jsonCtx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }

    String? lastError;
    var attemptUser = user;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      try {
        final raw = (await _text.complete(
          endpoint: endpoint,
          system: system,
          user: attemptUser,
          generation: jsonCtx.generation,
        ))
            .content;
        return map(raw);
      } on StageMapException catch (error) {
        lastError = error.message;
        if (attempt >= maxFormatRetries) break;
        attemptUser = '$user\n\n'
            '上次输出无法解析：$lastError\n'
            '请只输出合法 JSON，不要用 markdown 代码块，不要附加说明。';
      } on AiTextException {
        rethrow;
      } catch (error, stack) {
        AppLog.instance.error(
          '导入调用失败',
          tag: _logTag,
          error: error,
          stackTrace: stack,
        );
        rethrow;
      }
    }
    throw AiTextException(lastError ?? '生成结果无法识别，请重试');
  }

  static String _contextUser({
    required String heading,
    required NovelOutline outline,
    required String note,
    required List<String> samples,
  }) {
    final buf = StringBuffer();
    if (heading.trim().isNotEmpty) {
      buf.writeln(heading.trim());
      buf.writeln();
    }
    buf.writeln('大纲：');
    buf.writeln(outline.promptBlock);
    if (note.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('用户补充：')
        ..writeln(note.trim());
    }
    if (samples.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('抽样正文：');
      for (var i = 0; i < samples.length; i++) {
        buf
          ..writeln('—— 片段 ${i + 1} ——')
          ..writeln(samples[i]);
      }
    }
    return buf.toString().trim();
  }

  static String _outlinePartialLine(String raw) {
    try {
      final decoded = decodeJsonCandidate(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final points = map['points'];
        if (points is List) {
          return points
              .map((e) => e?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty)
              .join('；');
        }
        final summary = map['summary']?.toString().trim();
        if (summary != null && summary.isNotEmpty) return summary;
      }
    } catch (_) {
      // Fall through to trimmed raw.
    }
    final trimmed = raw.trim();
    if (trimmed.length <= 400) return trimmed;
    return trimmed.substring(0, 400);
  }

  static NovelOutline _outlineFromRaw(String raw) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const StageMapException('大纲结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final title = map['title']?.toString().trim() ?? '';
    final summary = map['summary']?.toString().trim() ?? '';
    if (summary.isEmpty && title.isEmpty) {
      throw const StageMapException('大纲里没有可用内容');
    }
    final conflictsRaw = map['conflicts'];
    final conflicts = <String>[];
    if (conflictsRaw is List) {
      for (final item in conflictsRaw) {
        final line = item?.toString().trim() ?? '';
        if (line.isNotEmpty) conflicts.add(line);
      }
    }
    return NovelOutline(
      title: title,
      summary: summary.isEmpty ? title : summary,
      conflicts: conflicts,
    );
  }

  static const String _chunkSummarySchema = '''
输出格式：
{"points":["要点1","要点2","要点3"]}
根据本段正文提炼 2～5 条剧情要点（人物、事件、冲突）。只输出 JSON，不要 markdown，不要解释。''';

  static const String _outlineReduceSchema = '''
输出格式：
{"title":"故事标题","summary":"主线概括","conflicts":["关键冲突1","关键冲突2"]}
合并各段要点成简洁大纲；title 短；summary 一两段；conflicts 0～5 条。只输出 JSON，不要 markdown，不要解释。''';

  static const String _worldSchema = '''
输出格式：
{"sections":[{"title":"世界观","body":"..."},{"title":"规则或禁忌","body":"..."}]}
根据大纲与抽样正文，写出 1～3 段简洁设定。只输出 JSON，不要 markdown，不要解释。''';

  static const String _castSchema = '''
输出格式：
{"cast":[{"name":"姓名","summary":"一句话","personality":"性格","speechStyle":"说话风格","exampleLines":["例句"]}]}
根据大纲与设定生成主要角色（约 2～6 人）；姓名要短、好记；标出与主线相关的人。只输出 JSON，不要 markdown，不要解释。''';
}
