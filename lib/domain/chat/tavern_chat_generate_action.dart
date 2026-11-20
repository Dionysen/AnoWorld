import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/play_context_selector.dart';
import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';

/// Assistant turn prose + optional reasoning from the model.
class TavernChatGenerateResult {
  const TavernChatGenerateResult({
    required this.content,
    this.reasoning,
  });

  final String content;
  final String? reasoning;
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

    final selection = const PlayContextSelector().select(
      project: project,
      plotCatalog: plotCatalog,
      recentText: _recentText(history),
    );
    final system = ctx.assemblePlaySystem(
      project: project,
      selection: selection,
      taskSuffix: task,
    );
    final buffer = StringBuffer()
      ..writeln('角色：${castNames.isEmpty ? '（无）' : castNames}')
      ..writeln('玩家：${ctx.persona?.name ?? 'User'}');
    if (plotHint.isNotEmpty) {
      buffer.writeln('情节提示（可选约束，不要生硬念出来）：$plotHint');
    }
    buffer.writeln('—— 对话记录 ——');
    if (history.isEmpty) {
      buffer.writeln('（尚无对话，请写开场第一段）');
    } else {
      for (final m in history) {
        final who = m.role == TavernChatRole.user
            ? (ctx.persona?.name ?? 'User')
            : '助手';
        buffer.writeln('$who：${m.content}');
      }
    }
    buffer.writeln('—— 请继续写助手这一轮 ——');

    final result = await _text.complete(
      endpoint: endpoint,
      system: system,
      user: buffer.toString(),
      generation: ctx.generation,
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
