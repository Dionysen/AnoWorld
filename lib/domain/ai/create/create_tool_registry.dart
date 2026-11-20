import 'package:anoworld/domain/ai/create/create_tool.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/ai/create/tools/card_tools.dart';
import 'package:anoworld/domain/ai/create/tools/project_tools.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';

class CreateToolRegistry {
  CreateToolRegistry({List<CreateTool>? tools}) {
    for (final tool in tools ?? defaultTools()) {
      _tools[tool.name] = tool;
      _wireToName[tool.wireName] = tool.name;
    }
  }

  /// Canonical (dotted) tool names: what prompts, logs and tests use.
  final Map<String, CreateTool> _tools = <String, CreateTool>{};

  /// Provider-safe names (`world_patch`) as sent in `tools[]`.
  final Map<String, String> _wireToName = <String, String>{};

  static List<CreateTool> defaultTools() => [
        ...buildCardTools(),
        ...buildProjectTools(),
      ];

  Iterable<CreateTool> get catalog => _tools.values;

  /// Looks a tool up by canonical name or by the wire name the model echoed.
  CreateTool? lookup(String name) =>
      _tools[name] ?? _tools[_wireToName[name]];

  /// Canonical name for a name the model used; unknown names come back as-is.
  String canonical(String name) {
    if (_tools.containsKey(name)) return name;
    return _wireToName[name] ?? name;
  }

  /// Name to put in a tool declaration (or echo back in `tool_calls`).
  String wireName(String name) {
    final tool = lookup(name);
    return tool?.wireName ?? CreateTool.wireNameOf(name);
  }

  /// Tools named in [names], skipping unknown names.
  List<CreateTool> allowed(List<String> names) => [
        for (final name in names)
          if (lookup(name) != null) lookup(name)!,
      ];

  /// Model-facing declarations for [names]; unknown names are skipped.
  List<OpenAiTool> declarations(List<String> names) =>
      [for (final tool in allowed(names)) tool.declaration()];

  Future<CreateToolResult> invoke(
    String name,
    CreateToolContext ctx, {
    Map<String, dynamic> args = const {},
  }) async {
    final tool = lookup(name);
    if (tool == null) {
      return CreateToolResult.error('未知工具：$name');
    }
    return tool.invoke(ctx, args);
  }
}
