import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/validation/project_issue.dart';

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
      description: '按 id 读取世界书正文（可截断）',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final id = args['id']?.toString() ?? '';
        final maxChars = (args['maxChars'] as num?)?.toInt() ?? 4000;
        for (final e in project.worldBook.entries) {
          if (e.id != id) continue;
          var body = e.body;
          if (body.length > maxChars) {
            body = '${body.substring(0, maxChars)}…';
          }
          return CreateToolResult.success(<String, dynamic>{
            'schemaVersion': 1,
            'id': e.id,
            'title': e.title,
            'body': body,
            'alwaysOn': e.alwaysOn,
            'keys': e.keys,
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
      description: '按 id 读取角色字段',
      mutatesProject: false,
      invoke: (ctx, args) async {
        final project = ctx.project;
        if (project == null) {
          return CreateToolResult.error('没有打开的故事');
        }
        final id = args['id']?.toString() ?? '';
        for (final c in project.cast) {
          if (c.id != id) continue;
          return CreateToolResult.success(<String, dynamic>{
            'schemaVersion': 1,
            'id': c.id,
            'name': c.name,
            'summary': c.summary,
            'personality': c.personality,
            'speechStyle': c.speechStyle,
            'exampleLines': c.exampleLines,
            'isProtagonist': c.isProtagonist,
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