import 'dart:convert';

import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_chat_turn.dart';
import 'package:anoworld/domain/ai/create/create_context_index.dart';
import 'package:anoworld/domain/ai/create/create_history_fit.dart';
import 'package:anoworld/domain/ai/create/create_prompt_profiles.dart';
import 'package:anoworld/domain/ai/create/create_proposals.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_registry.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/domain/ai/create/create_turn_result.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

/// One create-assistant turn as a real tool loop:
/// model picks a tool → tools run → model continues until it proposes a change
/// or answers in text.
///
/// Proposals no longer end the turn: they are staged (one per layer, repeated
/// patches on the same layer are merged) and the model is told it may keep
/// going, so a cross-layer turn can stage world + cast + graph in one go.
class CreateAgentLoop {
  CreateAgentLoop({
    CreateToolRegistry? registry,
    CreateProposals proposals = const CreateProposals(),
    this.maxSteps = 10,
  }) : _registry = registry ?? CreateToolRegistry(),
       _proposals = proposals;

  final CreateToolRegistry _registry;
  final CreateProposals _proposals;

  /// Upper bound on model turns. A single-layer edit needs 1–3; a cross-layer
  /// turn reads several layers and then writes each of them, so it needs more.
  final int maxSteps;

  /// Most recent conversation lines replayed into a turn. Ten lines covers
  /// "改一下 → 不行 → 再改" without dragging the whole transcript back in.
  static const int maxHistoryTurns = 10;

  Future<CreateAgentTurnResult> run({
    required CreateAssistantTarget target,
    required String prompt,
    required CreateToolContext ctx,
    List<CreateChatTurn> history = const <CreateChatTurn>[],
  }) async {
    final project = ctx.project;
    if (project == null) {
      return CreateAgentTurnResult.error('没有打开的故事');
    }
    final ai = ctx.ai;
    if (ai == null) {
      return CreateAgentTurnResult.error('未配置文本服务');
    }
    final client = ctx.services.toolClient;
    if (client == null) {
      return CreateAgentTurnResult.error('先用一个支持工具调用的服务');
    }
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return CreateAgentTurnResult.error('先说想改哪里');
    }

    final allow = target.toolAllowlist;
    final budget = ContextBudget.of(ai.generation);
    final system = _systemPrompt(target, ctx);
    final earlier = _fitHistory(history, budget, system, trimmed);
    final messages = <OpenAiChatMessage>[
      OpenAiChatMessage(role: 'system', content: system),
      for (final turn in earlier)
        OpenAiChatMessage(
          role: turn.fromUser ? 'user' : 'assistant',
          content: turn.text,
        ),
      OpenAiChatMessage(role: 'user', content: trimmed),
    ];
    final staged = <String, CreateTurnProposal>{};
    final called = <String>[];

    for (var step = 0; step < maxSteps; step++) {
      final turn = await _nextTurn(client, ai, messages, allow, budget);
      if (turn.toolCalls.isEmpty) {
        if (staged.isNotEmpty) {
          return _proposalBatch(staged, called, turn.content);
        }
        return _answerOrProposal(target, ctx, turn.content, called);
      }
      messages.add(
        OpenAiChatMessage(
          role: 'assistant',
          content: turn.content,
          toolCalls: turn.toolCalls,
        ),
      );
      for (final call in turn.toolCalls) {
        called.add(call.name);
        var result = await _registry.invoke(
          call.name,
          ctx,
          args: _decodeArgs(call.arguments),
        );
        AppLog.instance.info(
          '创作工具 ${call.name}${result.ok ? '' : ' 失败'}',
          tag: 'create.tool',
        );
        if (result.userConfirmPayload != null) {
          result = await _stage(staged, call.name, result, ctx);
        }
        final preview = result.userConfirmPayload;
        if (preview != null) {
          // Staged, not applied: tell the model so it can keep going on other
          // layers, then wait for the user's single confirmation.
          messages.add(
            OpenAiChatMessage(
              role: 'tool',
              toolCallId: call.id,
              content: jsonEncode(<String, dynamic>{
                'ok': true,
                'staged': preview['kind'] ?? call.name,
                'note': '已暂存，等用户一起确认；可以继续提交其他层的改动',
              }),
            ),
          );
          continue;
        }
        messages.add(
          OpenAiChatMessage(
            role: 'tool',
            toolCallId: call.id,
            content: jsonEncode(_envelope(result)),
          ),
        );
      }
    }

    if (staged.isNotEmpty) {
      // Out of steps but changes are staged: hand them over instead of
      // throwing the work away.
      return _proposalBatch(staged, called, '');
    }

    AppLog.instance.warning('创作回合用完 $maxSteps 步仍未给出改动', tag: 'create.tool');
    return CreateAgentTurnResult.error('这一步没走完，换个说法再试');
  }

  String _systemPrompt(CreateAssistantTarget target, CreateToolContext ctx) {
    final project = ctx.project!;
    final index = const CreateContextIndex().build(
      project: project,
      plotCatalog: ctx.services.plotCatalog,
      presetManager: ctx.ai!.promptManager,
      target: target,
    );
    return ctx.ai!.assembleSystem(
      project: project,
      plotCatalog: ctx.services.plotCatalog,
      inlineWorldBook: false,
      worldInfoBefore: index,
      taskSuffix: switch (target) {
        CreateAssistantTarget.graph => CreatePromptProfiles.graphTaskRules,
        CreateAssistantTarget.world => CreatePromptProfiles.worldTaskRules,
        CreateAssistantTarget.cast => CreatePromptProfiles.castTaskRules,
        CreateAssistantTarget.all => CreatePromptProfiles.allTaskRules,
      },
    );
  }

  /// Earlier conversation lines that fit beside the rules and this prompt.
  ///
  /// Two limits, newest first: at most [maxHistoryTurns] lines, then whatever
  /// the input budget still has room for. Older lines are dropped, never the
  /// newest, so "再冷一点" always has the line it refers to.
  List<CreateChatTurn> _fitHistory(
    List<CreateChatTurn> history,
    ContextBudget budget,
    String system,
    String prompt,
  ) {
    final nonEmpty = <CreateChatTurn>[
      for (final turn in history)
        if (turn.text.trim().isNotEmpty) turn,
    ];
    if (nonEmpty.isEmpty) return nonEmpty;
    final recent = nonEmpty.length <= maxHistoryTurns
        ? nonEmpty
        : nonEmpty.sublist(nonEmpty.length - maxHistoryTurns);
    final room = budget.remaining(
      budget.estimate(system) + budget.estimate(prompt),
    );
    final kept = budget.keepNewest(recent, (turn) => turn.text, tokens: room);
    if (kept.length < history.length) {
      AppLog.instance.info(
        '创作回合带上最近 ${kept.length} 条对话（共 ${history.length} 条）',
        tag: 'create.tool',
      );
    }
    return kept;
  }

  Future<_ModelTurn> _nextTurn(
    AiToolTurnClient client,
    AiPromptContext ai,
    List<OpenAiChatMessage> messages,
    List<String> allow,
    ContextBudget budget,
  ) async {
    final fitted = const CreateHistoryFit().fit(messages, budget: budget);
    if (fitted.elided > 0) {
      AppLog.instance.info(
        '创作回合超预算，省略 ${fitted.elided} 条较早的工具结果',
        tag: 'create.tool',
      );
    }
    final completion = await client.completeTurn(
      endpoint: ai.endpoint,
      messages: fitted.messages,
      tools: _registry.declarations(allow),
      generation: ai.generation,
    );
    return _ModelTurn(
      content: completion.content,
      toolCalls: completion.toolCalls,
    );
  }

  /// Records a proposal and returns the result the model should see.
  ///
  /// A second write on the same layer is merged with the first and re-validated
  /// as one patch, so the confirmation sheet shows the final ops instead of
  /// silently dropping the earlier batch. Ops the model repeats verbatim are
  /// ignored, so re-submitting the same patch cannot duplicate entries.
  Future<CreateToolResult> _stage(
    Map<String, CreateTurnProposal> staged,
    String toolName,
    CreateToolResult result,
    CreateToolContext ctx,
  ) async {
    final preview = result.userConfirmPayload!;
    final kind = preview['kind']?.toString() ?? toolName;
    final previous = staged[kind];
    if (previous == null) {
      staged[kind] = CreateTurnProposal(toolName: toolName, preview: preview);
      return result;
    }
    if (kind == 'main.replace') {
      // Whole-graph rewrites are all-or-nothing: the newest one wins.
      staged[kind] = CreateTurnProposal(toolName: toolName, preview: preview);
      return result;
    }
    final previousOps = _opsOf(previous.preview);
    final seen = previousOps.map(jsonEncode).toSet();
    final added = <Map<String, dynamic>>[
      for (final op in _opsOf(preview))
        if (seen.add(jsonEncode(op))) op,
    ];
    if (added.isEmpty) {
      // Nothing new: acknowledge the already staged patch and keep it.
      return CreateToolResult.userConfirmRequired(previous.preview);
    }
    final merged = await _registry.invoke(
      toolName,
      ctx,
      args: <String, dynamic>{
        'ops': <Map<String, dynamic>>[...previousOps, ...added],
      },
    );
    if (merged.userConfirmPayload == null) {
      AppLog.instance.warning(
        '创作工具 $kind 合并失败：${merged.errorMessage ?? '未知原因'}',
        tag: 'create.tool',
      );
      return merged;
    }
    staged[kind] = CreateTurnProposal(
      toolName: toolName,
      preview: merged.userConfirmPayload!,
    );
    return merged;
  }

  static List<Map<String, dynamic>> _opsOf(Map<String, dynamic> preview) {
    final raw = preview['ops'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  CreateAgentTurnResult _proposalBatch(
    Map<String, CreateTurnProposal> staged,
    List<String> called,
    String content,
  ) {
    final proposals = staged.values.toList(growable: false);
    AppLog.instance.info(
      '创作回合暂存 ${proposals.map((p) => p.kind).join(' → ')}',
      tag: 'create.tool',
    );
    return CreateAgentTurnResult(
      toolName: proposals.last.toolName,
      proposals: proposals,
      answer: content.trim(),
      calledTools: called,
    );
  }

  CreateAgentTurnResult _answerOrProposal(
    CreateAssistantTarget target,
    CreateToolContext ctx,
    String content,
    List<String> called,
  ) {
    final text = content.trim();
    if (text.isEmpty) {
      return CreateAgentTurnResult.error('模型没有给出改动');
    }
    final Map<String, dynamic>? proposal;
    try {
      proposal = _proposals.fromText(
        target: target,
        project: ctx.project!,
        raw: text,
        catalog: ctx.services.plotCatalog,
      );
    } on CreateProposalException catch (error) {
      return CreateAgentTurnResult.error(error.message);
    }
    if (proposal != null) {
      AppLog.instance.info(
        '创作助手按文本改动识别为 ${proposal['kind']}',
        tag: 'create.tool',
      );
      return CreateAgentTurnResult(
        toolName: '${proposal['kind']}',
        result: CreateToolResult.userConfirmRequired(proposal),
        proposals: [
          CreateTurnProposal(
            toolName: '${proposal['kind']}',
            preview: proposal,
          ),
        ],
        calledTools: called,
      );
    }
    if (text.startsWith('{')) {
      // A JSON-looking reply that is not a proposal: say so instead of dumping
      // raw ops into the chat.
      return CreateAgentTurnResult.error('这次改动没看懂，换个说法再试');
    }
    return CreateAgentTurnResult(answer: text, calledTools: called);
  }

  static Map<String, dynamic> _decodeArgs(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Fall through: the model sent something that is not JSON.
    }
    return const <String, dynamic>{};
  }

  /// Compact tool reply: what the model needs to decide the next step.
  static Map<String, dynamic> _envelope(CreateToolResult result) {
    if (!result.ok) {
      return <String, dynamic>{
        'ok': false,
        'error': result.errorMessage ?? '工具执行失败',
        if (result.validationIssues != null)
          'issues': [
            for (final issue in result.validationIssues!) issue.toString(),
          ],
      };
    }
    return <String, dynamic>{'ok': true, 'data': result.payload ?? const {}};
  }
}

class _ModelTurn {
  const _ModelTurn({required this.content, required this.toolCalls});

  final String content;
  final List<OpenAiToolCall> toolCalls;
}
