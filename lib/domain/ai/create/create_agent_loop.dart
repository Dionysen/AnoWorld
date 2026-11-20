import 'dart:convert';

import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_context_index.dart';
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
class CreateAgentLoop {
  CreateAgentLoop({
    CreateToolRegistry? registry,
    CreateProposals proposals = const CreateProposals(),
    this.maxSteps = 6,
  })  : _registry = registry ?? CreateToolRegistry(),
        _proposals = proposals;

  final CreateToolRegistry _registry;
  final CreateProposals _proposals;

  /// Upper bound on model turns; a normal turn needs 1–3.
  final int maxSteps;

  Future<CreateAgentTurnResult> run({
    required CreateAssistantTarget target,
    required String prompt,
    required CreateToolContext ctx,
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
    final messages = <OpenAiChatMessage>[
      OpenAiChatMessage(role: 'system', content: _systemPrompt(target, ctx)),
      OpenAiChatMessage(role: 'user', content: trimmed),
    ];
    final called = <String>[];

    for (var step = 0; step < maxSteps; step++) {
      final turn = await _nextTurn(client, ai, messages, allow);
      if (turn.toolCalls.isEmpty) {
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
        final result = await _registry.invoke(
          call.name,
          ctx,
          args: _decodeArgs(call.arguments),
        );
        AppLog.instance.info(
          '创作工具 ${call.name}${result.ok ? '' : ' 失败'}',
          tag: 'create.tool',
        );
        final preview = result.userConfirmPayload;
        if (preview != null) {
          return CreateAgentTurnResult(
            toolName: call.name,
            result: result,
            calledTools: called,
          );
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

    AppLog.instance.warning(
      '创作回合用完 $maxSteps 步仍未给出改动',
      tag: 'create.tool',
    );
    return CreateAgentTurnResult.error('这一步没走完，换个说法再试');
  }

  String _systemPrompt(CreateAssistantTarget target, CreateToolContext ctx) {
    final project = ctx.project!;
    final index = const CreateContextIndex().build(
      project: project,
      plotCatalog: ctx.services.plotCatalog,
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
      },
    );
  }

  Future<_ModelTurn> _nextTurn(
    AiToolTurnClient client,
    AiPromptContext ai,
    List<OpenAiChatMessage> messages,
    List<String> allow,
  ) async {
    final completion = await client.completeTurn(
      endpoint: ai.endpoint,
      messages: messages,
      tools: _registry.declarations(allow),
      generation: ai.generation,
    );
    return _ModelTurn(
      content: completion.content,
      toolCalls: completion.toolCalls,
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
