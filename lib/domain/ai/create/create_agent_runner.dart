import 'package:anoworld/domain/ai/create/create_agent_loop.dart';
import 'package:anoworld/domain/ai/create/create_chat_turn.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_registry.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/ai/create/create_turn_result.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

export 'package:anoworld/domain/ai/create/create_turn_result.dart';

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
    CreateAgentLoop? loop,
  })  : _registry = registry ?? CreateToolRegistry(),
        _loop = loop;

  final CreateToolRegistry _registry;
  final CreateAgentLoop? _loop;

  Future<CreateToolResult> runSingle({
    required String toolName,
    required CreateToolContext ctx,
    Map<String, dynamic> args = const {},
  }) async {
    AppLog.instance.info('调用 $toolName', tag: 'create.tool');
    final result = await _registry.invoke(toolName, ctx, args: args);
    if (!result.ok) {
      AppLog.instance.warning(
        '$toolName：${result.errorMessage ?? '失败'}',
        tag: 'create.tool',
      );
    }
    return result;
  }

  /// One assistant turn: the model reads what it needs, then proposes changes.
  ///
  /// [history] is the earlier conversation the user can still see, so follow-up
  /// asks ("再冷一点") have a referent; the loop trims it to the budget.
  Future<CreateAgentTurnResult> runTurn({
    required String prompt,
    required CreateToolContext ctx,
    List<CreateChatTurn> history = const <CreateChatTurn>[],
  }) async {
    AppLog.instance.info('创作回合开始', tag: 'create.tool');
    final result = await (_loop ?? CreateAgentLoop(registry: _registry)).run(
      prompt: prompt,
      ctx: ctx,
      history: history,
    );
    if (result.calledTools.isNotEmpty) {
      AppLog.instance.info(
        '创作回合调用 ${result.calledTools.join(' → ')}',
        tag: 'create.tool',
      );
    }
    return result;
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
}
