import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/card_import/card_import_sources.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';

List<CreateTool> buildCardTools({
  CardSanitizeAction? sanitizeAction,
  CardImportSources? sources,
}) {
  final sanitize = sanitizeAction ?? const CardSanitizeAction();
  final sourceList = sources ?? const CardImportSources();

  return [
    CreateTool(
      name: 'card.list_sources',
      description: '列出导入草稿中的素材片段',
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
  ];
}
