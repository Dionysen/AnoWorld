import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/ai/create/tools/card_tools.dart';
import 'package:anoworld/domain/ai/create/tools/project_tools.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';

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

  /// Tools named in [names], skipping unknown names.
  List<CreateTool> allowed(List<String> names) => [
        for (final name in names)
          if (_tools[name] != null) _tools[name]!,
      ];

  /// Model-facing declarations for [names]; unknown names are skipped.
  List<OpenAiTool> declarations(List<String> names) =>
      [for (final tool in allowed(names)) tool.declaration()];

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
