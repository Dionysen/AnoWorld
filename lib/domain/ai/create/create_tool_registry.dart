import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/ai/create/tools/card_tools.dart';
import 'package:anoworld/domain/ai/create/tools/project_tools.dart';

class CreateToolRegistry {
  CreateToolRegistry({List<CreateTool>? tools})
      : _tools = {for (final t in tools ?? defaultTools()) t.name: t};

  final Map<String, CreateTool> _tools;

  static List<CreateTool> defaultTools() => [
        ...buildCardTools(),
        ...buildProjectTools(),
      ];

  Iterable<CreateTool> get catalog => _tools.values;

  CreateTool? lookup(String name) => _tools[name];

  Future<CreateToolResult> invoke(
    String name,
    CreateToolContext ctx, {
    Map<String, dynamic> args = const {},
  }) async {
    final tool = _tools[name];
    if (tool == null) {
      return CreateToolResult.error('未知工具：$name');
    }
    return tool.invoke(ctx, args);
  }
}