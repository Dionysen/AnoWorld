import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/ai/generate_main_graph_action.dart';
import 'package:anoworld/domain/ai/propose_cast_patch_action.dart';
import 'package:anoworld/domain/ai/propose_main_graph_patch_action.dart';
import 'package:anoworld/domain/ai/propose_world_book_patch_action.dart';
import 'package:anoworld/domain/main/entity_ref.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/validation/project_issue.dart';
import 'package:anoworld/foundation/text/token_estimator.dart';

List<CreateTool> buildProjectTools() {
  return [
    CreateTool(
      name: 'project.validate',
      description: '校验故事包结构',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final result = ctx.services.validator.validate(project);
        if (result.hasErrors) {
          return CreateToolResult.validationFailed(result.issues);
        }
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'ok': true,
          'warningCount': result.issues
              .where((i) => i.severity == ProjectIssueSeverity.warning)
              .length,
        });
      },
    ),
    CreateTool(
      name: 'project.read_summary',
      description: '故事层概览（渐进披露入口）',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'projectId': project.meta.id,
          'title': project.meta.title,
          'worldBookEntryCount': project.worldBook.entries.length,
          'castCount': project.cast.length,
          'mainSummary': project.main.summary,
          'nodeCount': project.main.nodes.length,
          'edgeCount': project.main.edges.length,
        });
      },
    ),
    CreateTool(
      name: 'world.list_entries',
      description: '列出世界书条目 id 与标题',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'entries': project.worldBook.entries
              .map(
                (e) => <String, dynamic>{
                  'id': e.id,
                  'title': e.title,
                  'alwaysOn': e.alwaysOn,
                },
              )
              .toList(growable: false),
        });
      },
    ),
    CreateTool(
      name: 'world.read_entry',
      description: '按引用或 id 读取世界书条目（可截断、可只取一个字段）',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final ref = _resolveRef(args, EntityKind.worldBook);
        if (ref.error != null) return CreateToolResult.error(ref.error!);
        final maxChars = (args['maxChars'] as num?)?.toInt() ?? 4000;
        for (final e in project.worldBook.entries) {
          if (e.id != ref.value!.id) continue;
          final field = ref.value!.field;
          if (field != null) {
            return CreateToolResult.success(
              _fieldEnvelope(
                ref: ref.value!,
                field: field,
                value: _worldField(e, field),
                maxChars: maxChars,
              ),
            );
          }
          var body = e.body;
          final truncated = body.length > maxChars;
          if (truncated) {
            body = '${body.substring(0, maxChars)}…';
          }
          return CreateToolResult.success(<String, dynamic>{
            'schemaVersion': 1,
            'ref': ref.value!.format(),
            'id': e.id,
            'title': e.title,
            'body': body,
            'alwaysOn': e.alwaysOn,
            'keys': e.keys,
            'truncated': truncated,
            'tokenEstimate': TokenEstimator.estimate('${e.title}\n$body'),
          });
        }
        return CreateToolResult.error('找不到该设定');
      },
    ),
    CreateTool(
      name: 'cast.list_members',
      description: '列出角色 id 与姓名',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'cast': project.cast
              .map(
                (c) => <String, dynamic>{
                  'id': c.id,
                  'name': c.name,
                  'isProtagonist': c.isProtagonist,
                },
              )
              .toList(growable: false),
        });
      },
    ),
    CreateTool(
      name: 'cast.read_member',
      description: '按引用或 id 读取角色字段（可只取一个字段）',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final ref = _resolveRef(args, EntityKind.cast);
        if (ref.error != null) return CreateToolResult.error(ref.error!);
        for (final c in project.cast) {
          if (c.id != ref.value!.id) continue;
          final field = ref.value!.field;
          if (field != null) {
            return CreateToolResult.success(
              _fieldEnvelope(
                ref: ref.value!,
                field: field,
                value: _castField(c, field),
              ),
            );
          }
          return CreateToolResult.success(<String, dynamic>{
            'schemaVersion': 1,
            'ref': ref.value!.format(),
            'id': c.id,
            'name': c.name,
            'summary': c.summary,
            'personality': c.personality,
            'speechStyle': c.speechStyle,
            'exampleLines': c.exampleLines,
            'isProtagonist': c.isProtagonist,
            'tokenEstimate': TokenEstimator.estimate(
              [c.name, c.summary, c.personality, c.speechStyle]
                  .where((s) => s.trim().isNotEmpty)
                  .join('\n'),
            ),
          });
        }
        return CreateToolResult.error('找不到该角色');
      },
    ),
    CreateTool(
      name: 'main.read_graph',
      description: '读取主线紧凑骨架',
      mutatesProject: false,
      invoke: (ctx, _) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final graph = MainGraphDocument.encodeSkeleton(
          project.main,
          includeLayout: false,
        );
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'graph': graph,
        });
      },
    ),
    CreateTool(
      name: 'main.generate_graph',
      description: '按世界书与提示词写情节骨架（不落盘，等用户确认）',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final ai = ctx.ai;
        if (ai == null) {
          return CreateToolResult.error('未配置文本服务');
        }
        final prompt = args['prompt']?.toString().trim() ?? '';
        if (prompt.isEmpty) {
          return CreateToolResult.error('先说一句想要的走向');
        }
        try {
          final main = await GenerateMainGraphAction(
            textClient: ctx.services.textClient,
          ).generate(
            ctx: ai,
            project: project,
            prompt: prompt,
            plotCatalog: ctx.services.plotCatalog,
          );
          return CreateToolResult.userConfirmRequired(<String, dynamic>{
            'schemaVersion': 1,
            'kind': 'main.generate_graph',
            'summary': main.summary,
            'nodeCount': main.nodes.length,
            'branchCount':
                main.edges.where((e) => e.kind == EdgeKind.branch).length,
            'stations': [
              for (final node in main.nodes)
                <String, dynamic>{
                  'title': node.title,
                  if (node.synopsis != null) 'synopsis': node.synopsis,
                  'ending': node.tags.contains('ending'),
                },
            ],
            'graph': MainGraphDocument.encode(main),
          });
        } on AiTextException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'main.patch_graph',
      description: '按用户意图增量改情节骨架（不落盘，等用户确认）',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final ai = ctx.ai;
        if (ai == null) {
          return CreateToolResult.error('未配置文本服务');
        }
        final prompt = args['prompt']?.toString().trim() ?? '';
        if (prompt.isEmpty) {
          return CreateToolResult.error('先说想改哪里');
        }
        try {
          final proposal = await ProposeMainGraphPatchAction(
            textClient: ctx.services.textClient,
          ).propose(
            ctx: ai,
            project: project,
            prompt: prompt,
            plotCatalog: ctx.services.plotCatalog,
          );
          return CreateToolResult.userConfirmRequired(<String, dynamic>{
            'schemaVersion': 1,
            'kind': 'main.patch_graph',
            'opCount': proposal.ops.length,
            'ops': proposal.ops,
            'summary': proposal.main.summary,
            'nodeCount': proposal.main.nodes.length,
            'stations': [
              for (final node in proposal.main.nodes)
                <String, dynamic>{
                  'title': node.title,
                  if (node.synopsis != null) 'synopsis': node.synopsis,
                  'ending': node.tags.contains('ending'),
                },
            ],
            'graph': MainGraphDocument.encode(proposal.main),
          });
        } on AiTextException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'world.patch_propose',
      description: '按用户意图提议改世界书（不落盘，等用户确认）',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final ai = ctx.ai;
        if (ai == null) {
          return CreateToolResult.error('未配置文本服务');
        }
        final prompt = args['prompt']?.toString().trim() ?? '';
        if (prompt.isEmpty) {
          return CreateToolResult.error('先说想改哪条设定');
        }
        try {
          final proposal = await ProposeWorldBookPatchAction(
            textClient: ctx.services.textClient,
          ).propose(ctx: ai, project: project, prompt: prompt);
          return CreateToolResult.userConfirmRequired(<String, dynamic>{
            'schemaVersion': 1,
            'kind': 'world.patch_propose',
            'opCount': proposal.ops.length,
            'ops': proposal.ops,
            'entryCount': proposal.worldBook.entries.length,
            'entries': [
              for (final e in proposal.worldBook.entries)
                <String, dynamic>{
                  'id': e.id,
                  'title': e.title,
                  'alwaysOn': e.alwaysOn,
                },
            ],
            'worldBook': proposal.worldBook.toJson(),
          });
        } on AiTextException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'cast.patch_propose',
      description: '按用户意图提议改角色（不落盘，等用户确认）',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final ai = ctx.ai;
        if (ai == null) {
          return CreateToolResult.error('未配置文本服务');
        }
        final prompt = args['prompt']?.toString().trim() ?? '';
        if (prompt.isEmpty) {
          return CreateToolResult.error('先说想改哪个角色');
        }
        try {
          final proposal = await ProposeCastPatchAction(
            textClient: ctx.services.textClient,
          ).propose(ctx: ai, project: project, prompt: prompt);
          return CreateToolResult.userConfirmRequired(<String, dynamic>{
            'schemaVersion': 1,
            'kind': 'cast.patch_propose',
            'opCount': proposal.ops.length,
            'ops': proposal.ops,
            'castCount': proposal.cast.length,
            'cast': [
              for (final c in proposal.cast)
                <String, dynamic>{
                  'id': c.id,
                  'name': c.name,
                  'isProtagonist': c.isProtagonist,
                },
            ],
            'members': [
              for (final c in proposal.cast) c.toJson(),
            ],
          });
        } on AiTextException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'refine.field',
      description: 'P0.5 单字段润色扩写',
      mutatesProject: false,
      invoke: (_, _) async {
        return CreateToolResult.error('润色尚未开放');
      },
    ),
    CreateTool(
      name: 'ingest.segment',
      description: 'P1 长文分段导入',
      mutatesProject: false,
      invoke: (_, _) async {
        return CreateToolResult.error('分段导入尚未开放');
      },
    ),
  ];
}

/// Outcome of reading the `ref` / `id` arguments of a read tool.
class _RefArgs {
  const _RefArgs.value(EntityRef ref) : value = ref, error = null;

  const _RefArgs.error(String message) : value = null, error = message;

  final EntityRef? value;
  final String? error;
}

/// Reads `ref` when present (validating its layer), else falls back to `id`.
_RefArgs _resolveRef(Map<String, dynamic> args, EntityKind expected) {
  final raw = args['ref']?.toString().trim() ?? '';
  if (raw.isEmpty) {
    final id = args['id']?.toString().trim() ?? '';
    if (id.isEmpty) return const _RefArgs.error('缺少 ref 或 id');
    return _RefArgs.value(EntityRef(kind: expected, id: id));
  }
  final EntityRef parsed;
  try {
    parsed = EntityRef.parse(raw);
  } on EntityRefException catch (error) {
    return _RefArgs.error(error.message);
  }
  if (parsed.kind != expected) {
    return _RefArgs.error('这条引用不是${_kindLabel(expected)}：$raw');
  }
  return _RefArgs.value(parsed);
}

String _kindLabel(EntityKind kind) => switch (kind) {
      EntityKind.preset => '预设',
      EntityKind.worldBook => '设定',
      EntityKind.cast => '角色',
      EntityKind.node => '情节站',
      EntityKind.edge => '连线',
      EntityKind.plotElement => '剧情元素',
    };

/// Single-field reply shared by the read tools.
Map<String, dynamic> _fieldEnvelope({
  required EntityRef ref,
  required String field,
  required Object? value,
  int? maxChars,
}) {
  var out = value;
  var truncated = false;
  if (maxChars != null && out is String && out.length > maxChars) {
    out = '${out.substring(0, maxChars)}…';
    truncated = true;
  }
  final text = out is String
      ? out
      : (out is List ? out.join('\n') : '$out');
  return <String, dynamic>{
    'schemaVersion': 1,
    'ref': ref.format(),
    'id': ref.id,
    'field': field,
    'value': out,
    'truncated': truncated,
    'tokenEstimate': TokenEstimator.estimate(text),
  };
}

Object? _worldField(WorldBookEntry entry, String field) => switch (field) {
      'title' => entry.title,
      'body' => entry.body,
      'keys' => entry.keys,
      'alwaysOn' => entry.alwaysOn,
      _ => null,
    };

Object? _castField(CastMember member, String field) => switch (field) {
      'name' => member.name,
      'summary' => member.summary,
      'personality' => member.personality,
      'speechStyle' => member.speechStyle,
      'exampleLines' => member.exampleLines,
      'isProtagonist' => member.isProtagonist,
      _ => null,
    };