import 'package:anoworld/domain/ai/create/create_proposals.dart';
import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/main/entity_ref.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/validation/project_issue.dart';
import 'package:anoworld/foundation/text/token_estimator.dart';

/// Read + write tools for the three editable story layers.
///
/// Write tools never call the model themselves: the loop's model produces the
/// ops or the skeleton, these tools only validate and shape the proposal.
List<CreateTool> buildProjectTools() {
  const proposals = CreateProposals();
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
      description: '故事层概览：各层条目数量与主线概括',
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
      description: '列出世界书条目 id 与标题；正文用 world.read_entry 取。'
          '默认最多 $kListDefaultLimit 条，超出会标 truncated',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'keyword': stringSchema('只看标题、正文或关键词里含这个词的条目'),
          'limit': integerSchema(
            '最多返回多少条，默认 $kListDefaultLimit，最多 $kListMaxLimit',
          ),
        },
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final needle = _needleOf(args);
        final matched = <WorldBookEntry>[
          for (final e in project.worldBook.entries)
            if (needle.isEmpty || _worldEntryMatches(e, needle)) e,
        ];
        final page = _page(matched, args);
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'total': page.total,
          'count': page.rows.length,
          'truncated': page.truncated,
          if (page.truncated) 'hint': _listHint(page.rest),
          'entries': [
            for (final e in page.rows)
              <String, dynamic>{
                'id': e.id,
                'title': e.title,
                'alwaysOn': e.alwaysOn,
              },
          ],
        });
      },
    ),
    CreateTool(
      name: 'world.read_entry',
      description: '按引用或 id 读取世界书条目（可截断、可只取一个字段）',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'ref': stringSchema('条目引用，如 wb:wb_03 或 wb:wb_03.body'),
          'id': stringSchema('条目 id（没有 ref 时使用）'),
          'maxChars': integerSchema('正文最多返回多少字，默认 4000'),
        },
      ),
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
      description: '列出角色 id 与姓名；档案用 cast.read_member 取。'
          '默认最多 $kListDefaultLimit 人',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'keyword': stringSchema('只看姓名或简介里含这个词的角色'),
          'limit': integerSchema(
            '最多返回多少条，默认 $kListDefaultLimit，最多 $kListMaxLimit',
          ),
        },
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final needle = _needleOf(args);
        final matched = <CastMember>[
          for (final c in project.cast)
            if (needle.isEmpty || _castMemberMatches(c, needle)) c,
        ];
        final page = _page(matched, args);
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'total': page.total,
          'count': page.rows.length,
          'truncated': page.truncated,
          if (page.truncated) 'hint': _listHint(page.rest),
          'cast': [
            for (final c in page.rows)
              <String, dynamic>{
                'id': c.id,
                'name': c.name,
                'isProtagonist': c.isProtagonist,
              },
          ],
        });
      },
    ),
    CreateTool(
      name: 'cast.read_member',
      description: '按引用或 id 读取角色字段（可只取一个字段）',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'ref': stringSchema('角色引用，如 cast:c_02 或 cast:c_02.speechStyle'),
          'id': stringSchema('角色 id（没有 ref 时使用）'),
        },
      ),
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
      description: '读取主线紧凑骨架（站 id、站名、概括、连线）',
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
      name: 'main.list_nodes',
      description: '只列情节图的站（id、站名、出边数、是否终局），不返回概括与路径细节；'
          '整张图用 main.read_graph，细看一站用 main.get_node。'
          '默认最多 $kListDefaultLimit 站',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'keyword': stringSchema('只看站名或概括里含这个词的站'),
          'limit': integerSchema(
            '最多返回多少条，默认 $kListDefaultLimit，最多 $kListMaxLimit',
          ),
        },
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final main = project.main;
        if (!main.hasAuthoredNodes) {
          return CreateToolResult.error('还没有情节图');
        }
        final needle = _needleOf(args);
        final outDegree = <String, int>{};
        for (final edge in main.edges) {
          outDegree[edge.from] = (outDegree[edge.from] ?? 0) + 1;
        }
        final matched = <StoryNode>[
          for (final node in main.nodes)
            if (needle.isEmpty ||
                node.title.toLowerCase().contains(needle) ||
                (node.synopsis ?? '').toLowerCase().contains(needle))
              node,
        ];
        final page = _page(matched, args);
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'start': main.startNodeId,
          'total': page.total,
          'count': page.rows.length,
          'truncated': page.truncated,
          if (page.truncated) 'hint': _listHint(page.rest),
          'nodes': [
            for (final node in page.rows)
              <String, dynamic>{
                'id': node.id,
                'title': node.title,
                'exits': outDegree[node.id] ?? 0,
                'ending': node.tags.contains('ending'),
              },
          ],
        });
      },
    ),
    CreateTool(
      name: 'main.get_node',
      description: '读一站：概括、标签、出入连线；ref 如 node:n2 或 node:n2.synopsis',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'ref': stringSchema('站引用，如 node:n2 或 node:n2.synopsis'),
          'id': stringSchema('站 id（没有 ref 时使用）'),
        },
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final ref = _resolveRef(args, EntityKind.node);
        if (ref.error != null) return CreateToolResult.error(ref.error!);
        final main = project.main;
        final titles = <String, String>{
          for (final node in main.nodes) node.id: node.title,
        };
        for (final node in main.nodes) {
          if (node.id != ref.value!.id) continue;
          final field = ref.value!.field;
          if (field != null) {
            return CreateToolResult.success(
              _fieldEnvelope(
                ref: ref.value!,
                field: field,
                value: _nodeField(node, field),
              ),
            );
          }
          return CreateToolResult.success(<String, dynamic>{
            'schemaVersion': 1,
            'ref': ref.value!.format(),
            'id': node.id,
            'title': node.title,
            'synopsis': node.synopsis ?? '',
            'tags': node.tags,
            'ending': node.tags.contains('ending'),
            'isStart': node.id == main.startNodeId,
            'beats': node.beatIds.length,
            'exits': [
              for (final edge in main.edges)
                if (edge.from == node.id)
                  <String, dynamic>{
                    'id': edge.id,
                    'to': edge.to,
                    'toTitle': titles[edge.to],
                    'kind': edge.kind.wireName,
                    'label': edge.label,
                    'detail': edge.detail,
                  },
            ],
            'incoming': [
              for (final edge in main.edges)
                if (edge.to == node.id)
                  <String, dynamic>{
                    'id': edge.id,
                    'from': edge.from,
                    'fromTitle': titles[edge.from],
                    'kind': edge.kind.wireName,
                    'label': edge.label,
                  },
            ],
            'tokenEstimate': TokenEstimator.estimate(
              '${node.title}\n${node.synopsis ?? ''}',
            ),
          });
        }
        return CreateToolResult.error('找不到这一站');
      },
    ),
    CreateTool(
      name: 'main.replace',
      description: '提交整图重写：给 summary 与 stations（可带 edges）。'
          '没有情节图或用户要求整图重写时用；会替换现有情节图，等用户确认',
      mutatesProject: false,
      parameters: _graphParams(),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        try {
          return CreateToolResult.userConfirmRequired(
            proposals.replaceGraph(project, args),
          );
        } on CreateProposalException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'main.patch',
      description: '提交情节图局部改动 ops：改概括、增删站、增删连线。'
          '只给用户提到的部分，未提及的保持不动',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'ops': arraySchema(
            objectSchema(
              <String, dynamic>{
                'op': stringSchema(
                  'set_summary | upsert_node | remove_node | upsert_edge | remove_edge',
                ),
                'summary': stringSchema('set_summary 用：新主线概括'),
                'id': stringSchema(
                  '站 / 边 id；upsert 新条目时省略，改已有条目必须给',
                ),
                'title': stringSchema('upsert_node 用：站名'),
                'synopsis': stringSchema('upsert_node 用：本站要达成的剧情目标'),
                'ending': <String, dynamic>{
                  'type': 'boolean',
                  'description': 'upsert_node 用：这一站是否终局',
                },
                'from': stringSchema('upsert_edge 用：起点站 id 或站名'),
                'to': stringSchema('upsert_edge 用：终点站 id / 站名 / end'),
                'kind': stringSchema('upsert_edge 用：default 或 branch'),
                'label': stringSchema('upsert_edge 用：选项标注'),
                'detail': stringSchema('upsert_edge 用：这条路具体发生什么'),
              },
              const <String>['op'],
            ),
            description: '按顺序应用的改动列表',
          ),
        },
        const <String>['ops'],
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        try {
          return CreateToolResult.userConfirmRequired(
            proposals.patchGraph(project, args),
          );
        } on CreateProposalException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'world.patch',
      description: '提交世界书条目改动 ops：upsert_entry 新增或改写、remove_entry 删除。'
          '改已有条目必须带 id',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'ops': arraySchema(
            objectSchema(
              <String, dynamic>{
                'op': stringSchema('upsert_entry | remove_entry'),
                'id': stringSchema('条目 id；新增时省略，改写必须给'),
                'title': stringSchema('条目标题'),
                'body': stringSchema('正文：具体、可执行的事实'),
                'alwaysOn': <String, dynamic>{
                  'type': 'boolean',
                  'description': '是否无条件注入（全局硬规则与基调）',
                },
                'keys': arraySchema(
                  stringSchema('可命中该条目的关键词'),
                  description: '关键词列表',
                ),
              },
              const <String>['op'],
            ),
            description: '按顺序应用的改动列表',
          ),
        },
        const <String>['ops'],
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        try {
          return CreateToolResult.userConfirmRequired(
            proposals.patchWorldBook(project, args),
          );
        } on CreateProposalException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'cast.patch',
      description: '提交角色改动 ops：upsert_member 新增或改写、remove_member 删除。'
          '改已有角色必须带 id',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'ops': arraySchema(
            objectSchema(
              <String, dynamic>{
                'op': stringSchema('upsert_member | remove_member'),
                'id': stringSchema('角色 id；新增时省略，改写必须给'),
                'name': stringSchema('名字'),
                'summary': stringSchema('一句话说清身份与处境'),
                'personality': stringSchema('性格：行为倾向，不要形容词堆砌'),
                'speechStyle': stringSchema('说话方式'),
                'exampleLines': arraySchema(
                  stringSchema('一条口吻示例'),
                  description: '例句列表，每条一句',
                ),
                'isProtagonist': <String, dynamic>{
                  'type': 'boolean',
                  'description': '是否主角（全局最多一个）',
                },
              },
              const <String>['op'],
            ),
            description: '按顺序应用的改动列表',
          ),
        },
        const <String>['ops'],
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        try {
          return CreateToolResult.userConfirmRequired(
            proposals.patchCast(project, args),
          );
        } on CreateProposalException catch (error) {
          return CreateToolResult.error(error.message);
        }
      },
    ),
    CreateTool(
      name: 'plot.list_elements',
      description: '列出全局剧情元素库（id、分类、关键词、是否已选），'
          '可用 keyword 过滤；勾选或新增前先看这里。默认最多 $kListDefaultLimit 条',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'keyword': stringSchema('只看关键词里含这个词的条目'),
          'limit': integerSchema(
            '最多返回多少条，默认 $kListDefaultLimit，最多 $kListMaxLimit',
          ),
        },
      ),
      invoke: (ctx, args) async {
        final catalog = ctx.services.plotCatalog;
        if (catalog == null) {
          return CreateToolResult.error('剧情元素库还没准备好');
        }
        final needle = _needleOf(args);
        final selected = (ctx.project?.plotElements.selectedIds ?? const [])
            .toSet();
        final matched = <PlotElement>[
          for (final element in catalog.effectiveList)
            if (needle.isEmpty ||
                element.keyword.toLowerCase().contains(needle))
              element,
        ];
        final page = _page(matched, args);
        return CreateToolResult.success(<String, dynamic>{
          'schemaVersion': 1,
          'total': page.total,
          'count': page.rows.length,
          'truncated': page.truncated,
          if (page.truncated) 'hint': _listHint(page.rest),
          'elements': [
            for (final element in page.rows)
              <String, dynamic>{
                'id': element.id,
                'keyword': element.keyword,
                'category': catalog.categoryNameOf(element.categoryId),
                'selected': selected.contains(element.id),
              },
          ],
        });
      },
    ),
    CreateTool(
      name: 'plot.select',
      description: '提交剧情元素改动 ops：select 勾选、deselect 取消勾选、'
          'add_element 新建一条并勾上（会写进全局剧情元素库）',
      mutatesProject: false,
      parameters: objectSchema(
        <String, dynamic>{
          'ops': arraySchema(
            objectSchema(
              <String, dynamic>{
                'op': stringSchema('select | deselect | add_element'),
                'ids': arraySchema(
                  stringSchema('剧情元素 id，如 pe_xxx'),
                  description: 'select / deselect 要处理的条目',
                ),
                'keyword': stringSchema('add_element：触发用的关键词，如「暴雨封路」'),
                'description': stringSchema(
                  'add_element：一句话说明 + 一个可用的分叉示例，300 字内',
                ),
                'category': stringSchema('add_element：分类名，如 悬疑 / 危机；不确定就不填'),
              },
              const <String>['op'],
            ),
            description: '按顺序应用的改动列表',
          ),
        },
        const <String>['ops'],
      ),
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final catalog = ctx.services.plotCatalog;
        if (catalog == null) {
          return CreateToolResult.error('剧情元素库还没准备好');
        }
        try {
          return CreateToolResult.userConfirmRequired(
            proposals.patchPlot(project, catalog, args),
          );
        } on CreateProposalException catch (error) {
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

/// `main.replace` arguments: summary + stations (+ optional top-level edges).
Map<String, dynamic> _graphParams() {
  final exit = objectSchema(
    <String, dynamic>{
      'to': stringSchema('下一站站名 / 站 id / end'),
      'kind': stringSchema('default 或 branch'),
      'label': stringSchema('选项标注：选这条会怎样'),
      'detail': stringSchema('这条路具体发生什么（氛围与后果）'),
    },
    const <String>['to'],
  );
  final station = objectSchema(
    <String, dynamic>{
      'title': stringSchema('站名'),
      'synopsis': stringSchema('本站要达成的剧情目标，短'),
      'ending': <String, dynamic>{
        'type': 'boolean',
        'description': '是否终局；无出边的开放叶不要标',
      },
      'exits': arraySchema(exit, description: '本站的出边'),
    },
    const <String>['title', 'synopsis'],
  );
  return objectSchema(
    <String, dynamic>{
      'summary': stringSchema('主线概括'),
      'stations': arraySchema(station, description: '至少 20 站，上不封顶'),
      'edges': arraySchema(
        objectSchema(
          <String, dynamic>{
            'from': stringSchema('起点站名 / 站 id'),
            'to': stringSchema('终点站名 / 站 id / end'),
            'kind': stringSchema('default 或 branch'),
            'label': stringSchema('选项标注'),
            'detail': stringSchema('这条路具体发生什么'),
          },
          const <String>['from', 'to'],
        ),
        description: '跨站连线；与 station.exits 二选一即可',
      ),
    },
    const <String>['summary', 'stations'],
  );
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
  final text = out is String ? out : (out is List ? out.join('\n') : '$out');
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

/// Rows a `*.list_*` read returns when the model does not ask for a size.
const int kListDefaultLimit = 50;

/// Upper bound so one list call cannot flood the context window.
const int kListMaxLimit = 200;

/// Lower-cased `keyword` argument; empty when absent.
String _needleOf(Map<String, dynamic> args) =>
    (args['keyword']?.toString() ?? '').trim().toLowerCase();

/// First `limit` rows of [rows] plus how many were withheld.
({List<T> rows, int total, bool truncated, int rest}) _page<T>(
  List<T> rows,
  Map<String, dynamic> args,
) {
  final asked = (args['limit'] as num?)?.toInt() ?? kListDefaultLimit;
  final limit = asked < 1
      ? kListDefaultLimit
      : (asked > kListMaxLimit ? kListMaxLimit : asked);
  if (rows.length <= limit) {
    return (rows: rows, total: rows.length, truncated: false, rest: 0);
  }
  return (
    rows: rows.take(limit).toList(growable: false),
    total: rows.length,
    truncated: true,
    rest: rows.length - limit,
  );
}

String _listHint(int rest) =>
    '还有 $rest 条没列出，用 keyword 收窄，或把 limit 调大';

bool _worldEntryMatches(WorldBookEntry entry, String needle) {
  return entry.title.toLowerCase().contains(needle) ||
      entry.body.toLowerCase().contains(needle) ||
      entry.keys.any((key) => key.toLowerCase().contains(needle));
}

bool _castMemberMatches(CastMember member, String needle) {
  return member.name.toLowerCase().contains(needle) ||
      member.summary.toLowerCase().contains(needle);
}

Object? _nodeField(StoryNode node, String field) => switch (field) {
      'title' => node.title,
      'synopsis' => node.synopsis ?? '',
      'tags' => node.tags,
      _ => null,
    };

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
