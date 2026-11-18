import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/card_import/card_import_sources.dart';
import 'package:anoworld/domain/card_import/card_organize_action.dart';
import 'package:anoworld/domain/card_import/card_organize_mapper.dart';
import 'package:anoworld/domain/card_import/card_organize_models.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';

List<CreateTool> buildCardTools({
  CardSanitizeAction? sanitizeAction,
  CardOrganizeAction Function(CreateToolContext ctx)? organizeFactory,
  CardOrganizeMapper? organizeMapper,
  CardImportSources? sources,
}) {
  final sanitize = sanitizeAction ?? const CardSanitizeAction();
  final sourceList = sources ?? const CardImportSources();
  final mapper = organizeMapper ?? const CardOrganizeMapper();

  return [
    CreateTool(
      name: 'card.list_sources',
      description: '列出导入草稿中的可整理素材片段',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final draft = ctx.draft;
        if (draft == null) {
          return CreateToolResult.error('没有导入草稿');
        }
        final rows = sourceList.fromDraft(draft);
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'sources': rows.map((e) => e.toJson()).toList(growable: false),
        });
      },
    ),
    CreateTool(
      name: 'card.sanitize_draft',
      description: '去掉 HTML，保留 Markdown',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final draft = ctx.draft;
        if (draft == null) {
          return CreateToolResult.error('没有导入草稿');
        }
        final result = sanitize.run(draft);
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'changedFieldCount': result.changedFieldCount,
          'samples': result.samples
              .map(
                (s) => <String, dynamic>{
                  'label': s.label,
                  'before': s.before,
                  'after': s.after,
                },
              )
              .toList(growable: false),
          'draftTitle': result.draft.title,
        });
      },
    ),
    CreateTool(
      name: 'card.organize_propose',
      description: 'AI 分类整理提议（不落盘）',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final draft = ctx.draft;
        final ai = ctx.ai;
        if (draft == null) {
          return CreateToolResult.error('没有导入草稿');
        }
        if (ai == null) {
          return CreateToolResult.error('未配置文本服务');
        }
        final action = organizeFactory?.call(ctx) ??
            CardOrganizeAction(textClient: ctx.services.textClient);
        final proposal = await action.propose(ctx: ai, draft: draft);
        return CreateToolResult.userConfirmRequired(<String, dynamic>{
          'schemaVersion': 1,
          'changes': proposal.changes
              .map(
                (c) => <String, dynamic>{'label': c.label, 'detail': c.detail},
              )
              .toList(growable: false),
        });
      },
    ),
    CreateTool(
      name: 'card.organize_apply',
      description: '应用经用户确认的整理 JSON',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final draft = ctx.draft;
        if (draft == null) {
          return CreateToolResult.error('没有导入草稿');
        }
        final opsRaw = args['operations'];
        if (opsRaw is! List) {
          return CreateToolResult.error('缺少 operations');
        }
        final ops = <CardOrganizeOperation>[];
        for (final item in opsRaw) {
          if (item is! Map) continue;
          ops.add(
            CardOrganizeOperation.fromJson(Map<String, dynamic>.from(item)),
          );
        }
        try {
          final proposal = mapper.applyOperations(draft, ops);
          return CreateToolResult.success(<String, dynamic>{
            'schemaVersion': 1,
            'draftTitle': proposal.draftAfter.title,
            'changeCount': proposal.changes.length,
          });
        } on CardOrganizeException catch (e) {
          return CreateToolResult.error(e.message);
        }
      },
    ),
  ];
}