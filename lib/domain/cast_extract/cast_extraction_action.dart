import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/cast_extract/cast_extraction_models.dart';
import 'package:anoworld/domain/cast_extract/cast_merge.dart';
import 'package:anoworld/domain/cast_extract/cast_scan.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

class CastExtractionResult {
  const CastExtractionResult({
    this.characters = const <ExtractedCast>[],
    this.discarded = 0,
    this.batches = 0,
  });

  final List<ExtractedCast> characters;

  /// Rows dropped by the literal gate (the model named something not in text).
  final int discarded;
  final int batches;
}

/// Pulls structured characters out of world-book text with one strict JSON
/// contract per batch, then verifies every literal field.
class CastExtractionAction {
  CastExtractionAction({
    required AiTextClient textClient,
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final int maxFormatRetries;

  static const String _taskSuffix = '''你是角色资料整理助手。从给定世界书片段中找出「角色」，整理成结构化字段。
只输出 JSON，不要解释，不要 markdown。
格式：
{"characters":[{"name":"","aliases":[],"summary":"","personality":"","speechStyle":"","exampleLines":[],"visualTags":"","source":""}]}
规则：
- 只写片段中明确出现的角色；不要编造，不要把地名、门派、物品当角色。
- name 用片段里的称呼；aliases 写同一角色的别称、称号、昵称，必须原文出现。
- summary 写身份、背景、与他人的关系。
- personality 写性格与行为方式。
- speechStyle 写语气、口癖。
- exampleLines 摘录原文里该角色说过的台词，原样照抄，最多 3 条。
- visualTags 只写外貌特征，用短词，逗号分隔。
- source 写这段文字来自哪个条目标题。
- 信息不足的字段留空字符串或空数组。''';

  Future<CastExtractionResult> extract({
    required AiPromptContext ctx,
    required CastScanResult scan,
    int maxCharsPerBatch = 6000,
    String playerName = '玩家',
    void Function(int done, int total)? onProgress,
  }) async {
    if (scan.isEmpty) return const CastExtractionResult();
    final batches = _batch(scan.windows, maxCharsPerBatch);
    AppLog.instance.info(
      '角色抽取：${scan.scannedEntries} 条设定，${batches.length} 批',
      tag: 'cast.extract',
    );

    final collected = <ExtractedCast>[];
    var discarded = 0;
    for (var i = 0; i < batches.length; i++) {
      final sourceText = batches[i]
          .map((w) => '## ${w.entryTitle}\n${w.text}')
          .join('\n\n');
      final rows = await _extractBatch(
        ctx: ctx,
        sourceText: sourceText,
      );
      for (final row in rows) {
        final gated = gateExtractedCast(
          row,
          sourceText,
          playerName: playerName,
          sourceEntry: batches[i].first.entryTitle,
        );
        if (gated == null) {
          discarded++;
          continue;
        }
        collected.add(gated);
      }
      onProgress?.call(i + 1, batches.length);
    }

    AppLog.instance.info(
      '角色抽取完成：${collected.length} 名，跳过 $discarded 处对不上原文',
      tag: 'cast.extract',
    );
    return CastExtractionResult(
      characters: collected,
      discarded: discarded,
      batches: batches.length,
    );
  }

  Future<List<ExtractedCast>> _extractBatch({
    required AiPromptContext ctx,
    required String sourceText,
  }) async {
    final system = ctx.assembleSystem(
      inlineWorldBook: false,
      taskSuffix: _taskSuffix,
    );
    final user = '世界书片段如下，请整理其中的角色：\n\n$sourceText';
    Object? lastError;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      try {
        final completion = await _text.complete(
          endpoint: ctx.endpoint,
          system: system,
          user: attempt == 0
              ? user
              : '$user\n\n上次输出不合规（$lastError）。只输出合法 JSON。',
          generation: ctx.generation,
        );
        final decoded = decodeJsonCandidate(completion.content);
        if (decoded is! Map) throw const CastExtractionException('不是有效 JSON');
        final rows = decoded['characters'];
        if (rows is! List) return const <ExtractedCast>[];
        return <ExtractedCast>[
          for (final row in rows)
            if (row is Map) ExtractedCast.fromJson(row),
        ].where((c) => c.name.isNotEmpty).toList(growable: false);
      } catch (error) {
        lastError = error;
        if (attempt >= maxFormatRetries) {
          AppLog.instance.warning(
            '角色抽取批次失败：$error',
            tag: 'cast.extract',
          );
          return const <ExtractedCast>[];
        }
      }
    }
    return const <ExtractedCast>[];
  }

  static List<List<CastScanWindow>> _batch(
    List<CastScanWindow> windows,
    int maxChars,
  ) {
    final batches = <List<CastScanWindow>>[];
    var current = <CastScanWindow>[];
    var size = 0;
    for (final window in windows) {
      final cost = window.text.length + window.entryTitle.length + 4;
      if (current.isNotEmpty && size + cost > maxChars) {
        batches.add(current);
        current = <CastScanWindow>[];
        size = 0;
      }
      current.add(window);
      size += cost;
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }
}

class CastExtractionException implements Exception {
  const CastExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}
