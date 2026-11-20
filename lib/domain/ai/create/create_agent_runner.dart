import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_registry.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

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

  /// One assistant turn: pick a tool inside [target]'s allowlist (rule-based).
  Future<CreateAgentTurnResult> runTurn({
    required CreateAssistantTarget target,
    required String prompt,
    required CreateToolContext ctx,
  }) async {
    final toolName = _pickTool(target, prompt, ctx);
    final allow = target.toolAllowlist;
    if (!allow.contains(toolName)) {
      return CreateAgentTurnResult(
        toolName: toolName,
        result: CreateToolResult.error('该目标不能用 $toolName'),
      );
    }
    AppLog.instance.info(
      '创作回合 ${target.wireName} → $toolName',
      tag: 'create.tool',
    );
    final result = await runSingle(
      toolName: toolName,
      ctx: ctx,
      args: <String, dynamic>{'prompt': prompt},
    );
    return CreateAgentTurnResult(toolName: toolName, result: result);
  }

  static String _pickTool(
    CreateAssistantTarget target,
    String prompt,
    CreateToolContext ctx,
  ) {
    switch (target) {
      case CreateAssistantTarget.world:
        return 'world.patch_propose';
      case CreateAssistantTarget.cast:
        return 'cast.patch_propose';
      case CreateAssistantTarget.graph:
        final hasGraph = ctx.project?.main.hasAuthoredNodes ?? false;
        if (!hasGraph || wantsFullGraphRewrite(prompt)) {
          return 'main.generate_graph';
        }
        return 'main.patch_graph';
    }
  }

  /// User asked to replace the whole plot graph.
  static bool wantsFullGraphRewrite(String prompt) {
    final t = prompt.trim();
    if (t.isEmpty) return false;
    const markers = <String>[
      '整图重写',
      '全部重写',
      '重写全部',
      '重新生成全部',
      '替换情节',
      '替换整图',
      '重做情节图',
      '重写情节图',
      '从头生成',
    ];
    for (final m in markers) {
      if (t.contains(m)) return true;
    }
    return false;
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

class CreateAgentTurnResult {
  const CreateAgentTurnResult({
    required this.toolName,
    required this.result,
  });

  final String toolName;
  final CreateToolResult result;
}
