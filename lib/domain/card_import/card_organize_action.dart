import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/domain/ai/create/create_prompt_profiles.dart';
import 'package:anoworld/domain/card_import/card_import_sources.dart';
import 'package:anoworld/domain/card_import/card_organize_character_names.dart';
import 'package:anoworld/domain/card_import/card_organize_heuristic.dart';
import 'package:anoworld/domain/card_import/card_organize_operation_sanitizer.dart';
import 'package:anoworld/domain/card_import/card_organize_mapper.dart';
import 'package:anoworld/domain/card_import/card_organize_models.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

class CardOrganizeAction {
  CardOrganizeAction({
    required AiTextClient textClient,
    this.sources = const CardImportSources(),
    this.mapper = const CardOrganizeMapper(),
    this.heuristic = const CardOrganizeHeuristic(),
    this.sanitizer = const CardOrganizeOperationSanitizer(),
    this.maxFormatRetries = 2,
  }) : _text = textClient;

  final AiTextClient _text;
  final CardImportSources sources;
  final CardOrganizeMapper mapper;
  final CardOrganizeHeuristic heuristic;
  final CardOrganizeOperationSanitizer sanitizer;
  final int maxFormatRetries;

  static String get _organizeSystem => CreatePromptProfiles.organizeCardTaskSuffix;

  Future<CardOrganizeProposal> propose({
    required AiPromptContext ctx,
    required StCardImportDraft draft,
  }) async {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }

    final sourceRows = sources.fromDraft(draft);
    if (sourceRows.isEmpty) {
      throw const CardOrganizeException('没有可整理的素材');
    }

    final user = _buildUserMessage(draft, sourceRows);

    Object? lastError;
    try {
      final llm = await _proposeFromModel(
        draft: draft,
        sourceRows: sourceRows,
        endpoint: endpoint,
        generation: ctx.generation,
        user: user,
      );
      if (_isUsefulProposal(llm)) return llm;
    } catch (error) {
      lastError = error;
    }

    final ruleOps = heuristic.buildOperations(draft);
    if (ruleOps.isNotEmpty) {
      try {
        final ruled = mapper.applyOperations(draft, ruleOps);
        if (ruled.changes.isNotEmpty) return ruled;
      } catch (error) {
        lastError = error;
      }
    }

    final msg = lastError is CardOrganizeException
        ? lastError.message
        : lastError?.toString();
    throw CardOrganizeException(
      msg ?? '未识别到可拆的角色段落，检查世界书是否有人名录或【名】分段',
    );
  }

  bool _isUsefulProposal(CardOrganizeProposal proposal) {
    if (proposal.changes.isEmpty) return false;
    const castLabels = {'从设定拆出角色', '从设定抽出角色', '归到已有角色'};
    final castDetails = proposal.changes
        .where((c) => castLabels.contains(c.label))
        .map((c) => c.detail.trim())
        .where((d) => d.isNotEmpty);
    if (castDetails.isEmpty) return true;
    return castDetails.every(
      (name) => !CardOrganizeCharacterNames.isFieldLabel(name),
    );
  }

  Future<CardOrganizeProposal> _proposeFromModel({
    required StCardImportDraft draft,
    required List<CardImportSource> sourceRows,
    required AiTextEndpoint endpoint,
    required GenerationPreset generation,
    required String user,
  }) async {
    String? lastError;
    var attemptUser = user;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      final raw = (await _text.complete(
        endpoint: endpoint,
        system: _organizeSystem,
        user: attemptUser,
        generation: generation,
      ))
          .content;
      try {
        var ops = _parseOperations(raw);
        if (ops.every((o) => o.op == 'noop')) {
          throw const CardOrganizeException('模型未返回有效操作');
        }
        ops = sanitizer.filter(ops, sourceRows);
        if (ops.isEmpty) {
          throw const CardOrganizeException('模型未返回有效操作');
        }
        return mapper.applyOperations(draft, ops);
      } on CardOrganizeException catch (error) {
        lastError = error.message;
        if (attempt >= maxFormatRetries) break;
        attemptUser = '$user\n\n上次无法应用：$lastError\n请修正 JSON。';
      } catch (error) {
        lastError = error.toString();
        if (attempt >= maxFormatRetries) break;
        attemptUser = '$user\n\n解析失败：$lastError\n请只输出合法 JSON。';
      }
    }
    throw CardOrganizeException(lastError ?? '整理失败，请重试');
  }

  List<CardOrganizeOperation> parseOperationsJson(String raw) => _parseOperations(raw);

  static String _buildUserMessage(
    StCardImportDraft draft,
    List<CardImportSource> sourceRows,
  ) {
    final buffer = StringBuffer()..writeln('故事名：${draft.title}');
    buffer.writeln('角色条目 id（castItemId）：');
    for (final item in draft.castItems) {
      buffer.writeln('- ${item.id}：${item.title}');
    }
    buffer.writeln(
      '\n任务：检查每条 worldBook.body；一条里多名角色用 split_cast；'
      '单段归已有用 extract_to_cast；新配角用 add_cast；纯世界观 noop 或 update_world。',
    );
    buffer.writeln('\n来源素材（fromSourceId → 正文）：');
    for (final s in sourceRows) {
      buffer.writeln('---');
      buffer.writeln('id: ${s.id}');
      buffer.writeln('kind: ${s.kind}');
      buffer.writeln('title: ${s.title}');
      buffer.writeln('body:\n${s.body}');
    }
    return buffer.toString();
  }

  List<CardOrganizeOperation> _parseOperations(String raw) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const CardOrganizeException('整理结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final opsRaw = map['operations'];
    if (opsRaw is! List || opsRaw.isEmpty) {
      throw const CardOrganizeException('没有整理操作');
    }
    final ops = <CardOrganizeOperation>[];
    for (final item in opsRaw) {
      if (item is! Map) continue;
      ops.add(CardOrganizeOperation.fromJson(Map<String, dynamic>.from(item)));
    }
    if (ops.isEmpty) {
      throw const CardOrganizeException('没有整理操作');
    }
    return ops;
  }
}