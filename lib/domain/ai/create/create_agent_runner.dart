import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_registry.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';

class CreatePipelineStepResult {
  const CreatePipelineStepResult({
    required this.toolName,
    required this.result,
    required this.updatedContext,
  });

  final String toolName;
  final CreateToolResult result;
  final CreateToolContext updatedContext;
}

class CreateAgentRunner {
  CreateAgentRunner({
    CreateToolRegistry? registry,
  }) : _registry = registry ?? CreateToolRegistry();

  final CreateToolRegistry _registry;

  CreateToolRegistry get registry => _registry;

  Future<CreateToolResult> runSingle({
    required String toolName,
    required CreateToolContext ctx,
    Map<String, dynamic> args = const {},
  }) {
    return _registry.invoke(toolName, ctx, args: args);
  }

  Future<List<CreatePipelineStepResult>> runPipeline({
    required List<String> toolNames,
    required CreateToolContext ctx,
    Map<String, Map<String, dynamic>> argsByTool = const {},
  }) async {
    final out = <CreatePipelineStepResult>[];
    var current = ctx;
    for (final name in toolNames) {
      final result = await _registry.invoke(
        name,
        current,
        args: argsByTool[name] ?? const {},
      );
      current = _contextAfterStep(name, result, current);
      out.add(
        CreatePipelineStepResult(
          toolName: name,
          result: result,
          updatedContext: current,
        ),
      );
      if (!result.ok && result.userConfirmPayload == null) break;
    }
    return out;
  }

  CreateToolContext _contextAfterStep(
    String toolName,
    CreateToolResult result,
    CreateToolContext before,
  ) {
    if (toolName == 'card.sanitize_draft' && result.ok && before.draft != null) {
      // UI applies sanitize to draft explicitly; runner keeps context unchanged.
      return before;
    }
    return before;
  }
}