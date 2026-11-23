import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

/// Assistant turn prose + optional reasoning from the model.
class TavernChatGenerateResult {
  const TavernChatGenerateResult({
    required this.content,
    this.reasoning,
  });

  final String content;
  final String? reasoning;
}

/// One streamed piece of the assistant turn.
class TavernChatChunk {
  const TavernChatChunk({this.content = '', this.reasoning = ''});

  final String content;
  final String reasoning;
}

/// Generates the next assistant reply in a tavern-style chat (one user → one AI).
class TavernChatGenerateAction {
  TavernChatGenerateAction({required AiTextClient textClient})
      : _text = textClient;

  final AiTextClient _text;

  Future<TavernChatGenerateResult> generate({
    required AiPromptContext ctx,
    required Project project,
    required List<TavernChatMessage> history,
    PlotElementCatalog? plotCatalog,
  }) async {
    final request = _buildRequest(
      ctx: ctx,
      project: project,
      history: history,
      plotCatalog: plotCatalog,
    );
    final result = await _text.complete(
      endpoint: request.endpoint,
      system: request.system,
      user: request.user,
      generation: request.generation,
    );
    final out = result.content.trim();
    if (out.isEmpty) {
      throw AiTextException('这一轮没有写出内容，请重试');
    }
    final reasoning = result.reasoning?.trim();
    return TavernChatGenerateResult(
      content: out,
      reasoning: reasoning == null || reasoning.isEmpty ? null : reasoning,
    );
  }

  /// Same turn as [generate], delivered while the model writes it.
  ///
  /// Falls back to a single whole chunk when the client cannot stream.
  Stream<TavernChatChunk> streamGenerate({
    required AiPromptContext ctx,
    required Project project,
    required List<TavernChatMessage> history,
    PlotElementCatalog? plotCatalog,
  }) async* {
    final request = _buildRequest(
      ctx: ctx,
      project: project,
      history: history,
      plotCatalog: plotCatalog,
    );
    final streaming =
        _text is AiTextStreamClient ? _text as AiTextStreamClient : null;
    if (streaming == null) {
      final result = await generate(
        ctx: ctx,
        project: project,
        history: history,
        plotCatalog: plotCatalog,
      );
      yield TavernChatChunk(
        content: result.content,
        reasoning: result.reasoning ?? '',
      );
      return;
    }

    final content = StringBuffer();
    await for (final chunk in streaming.streamText(
      endpoint: request.endpoint,
      system: request.system,
      user: request.user,
      generation: request.generation,
    )) {
      if (chunk.isEmpty) continue;
      content.write(chunk.content);
      yield TavernChatChunk(
        content: chunk.content,
        reasoning: chunk.reasoning,
      );
    }
    if (content.toString().trim().isEmpty) {
      throw AiTextException('这一轮没有写出内容，请重试');
    }
  }

  ({AiTextEndpoint endpoint, String system, String user, GenerationPreset? generation})
      _buildRequest({
    required AiPromptContext ctx,
    required Project project,
    required List<TavernChatMessage> history,
    PlotElementCatalog? plotCatalog,
  }) {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }

    final plotHint = _plotHint(project);
    final castNames = project.cast.map((c) => c.name).join('、');
    final task = '''你是角色扮演聊天助手，按酒馆对话方式回复。
只输出这一轮要说的正文（可含旁白与对白），不要 markdown，不要 JSON。
不要替玩家说话，不要写玩家的台词或「User：」「{{user}}：」。
有多名角色时可写不同角色开口，但整段作为助手的一轮回复。''';

    final userName = ctx.persona?.name ?? 'User';
    String lineOf(TavernChatMessage m) {
      final who = m.role == TavernChatRole.user ? userName : '助手';
      return '$who：${m.content}';
    }

    final head = StringBuffer()
      ..writeln('角色：${castNames.isEmpty ? '（无）' : castNames}')
      ..writeln('玩家：$userName');
    if (plotHint.isNotEmpty) {
      head.writeln('情节提示（可选约束，不要生硬念出来）：$plotHint');
    }
    head.writeln('—— 对话记录 ——');
    const tailLine = '—— 请继续写助手这一轮 ——';

    final budget = ContextBudget.of(ctx.generation);
    final headText = head.toString();
    // Reserve room for at least the newest turn before picking lore.
    final system = ctx.assemblePlaySystem(
      project: project,
      plotCatalog: plotCatalog,
      recentText: _recentText(history),
      taskSuffix: task,
      budget: budget,
      reservedTokens: budget.estimate(headText) +
          budget.estimate(tailLine) +
          (history.isEmpty ? 0 : budget.estimate(lineOf(history.last))),
    );

    // Old turns fall off once 上下文长度 is small; the newest turn always stays
    // so the reply has something to answer.
    final reserved = budget.estimate(system) +
        budget.estimate(headText) +
        budget.estimate(tailLine);
    final kept = budget.keepNewest(
      history,
      lineOf,
      tokens: budget.remaining(reserved),
      minItems: 1,
    );

    final buffer = StringBuffer(headText);
    if (history.isEmpty) {
      buffer.writeln('（尚无对话，请写开场第一段）');
    } else {
      final dropped = history.length - kept.length;
      if (dropped > 0) {
        buffer.writeln('（更早的 $dropped 条对话已省略）');
        AppLog.instance.info(
          '上下文超出预算，省略最早 $dropped 条对话',
          tag: 'play.chat',
        );
      }
      for (final m in kept) {
        buffer.writeln(lineOf(m));
      }
    }
    buffer.writeln(tailLine);

    return (
      endpoint: endpoint,
      system: system,
      user: buffer.toString(),
      generation: ctx.generation,
    );
  }

  /// Last few turns are what a new reply is actually about; the whole chat
  /// would only add noise to keyword matching.
  static List<String> _recentText(List<TavernChatMessage> history) {
    final recent =
        history.length <= 6 ? history : history.sublist(history.length - 6);
    return <String>[for (final message in recent) message.content];
  }

  static String _plotHint(Project project) {
    final parts = <String>[];
    final summary = project.main.summary.trim();
    if (summary.isNotEmpty) parts.add(summary);
    final start = project.main.nodeById(project.main.startNodeId);
    final syn = start?.synopsis?.trim();
    if (syn != null && syn.isNotEmpty) parts.add('开场目标：$syn');
    if (project.main.nodes.length > 1) {
      final titles = project.main.nodes
          .take(6)
          .map((n) => n.title.trim())
          .where((t) => t.isNotEmpty)
          .join(' → ');
      if (titles.isNotEmpty) parts.add('大站：$titles');
    }
    return parts.join('；');
  }
}
