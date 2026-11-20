import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/play_context_selector.dart';
import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

/// Suggests clickable user reply lines after an assistant turn (NT ChatChoice).
class TavernReplyChoiceAction {
  TavernReplyChoiceAction({
    required AiTextClient textClient,
    this.choiceCount = 3,
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final int choiceCount;
  final int maxFormatRetries;

  Future<List<String>> generate({
    required AiPromptContext ctx,
    required Project project,
    required List<TavernChatMessage> history,
    PlotElementCatalog? plotCatalog,
  }) async {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      return const [];
    }
    final n = choiceCount.clamp(2, 6);
    final task = '''你为玩家生成可点击发送的回复选项。
只输出 JSON：{"choices":["选项1","选项2"]}
必须恰好 $n 条不重复、非空的短句（像玩家会说的话）。
不要 markdown，不要编号。''';
    final recent =
        history.length <= 8 ? history : history.sublist(history.length - 8);
    final selection = const PlayContextSelector().select(
      project: project,
      plotCatalog: plotCatalog,
      recentText: <String>[for (final message in recent) message.content],
    );
    final system = ctx.assemblePlaySystem(
      project: project,
      selection: selection,
      taskSuffix: task,
    );
    final transcript = recent.map((m) {
      final who = m.role == TavernChatRole.user ? '玩家' : '助手';
      return '$who：${m.content}';
    }).join('\n');
    final user = '根据当前情景给出 $n 条玩家回复选项。\n$transcript';

    String? lastError;
    var attemptUser = user;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      final raw = (await _text.complete(
        endpoint: endpoint,
        system: system,
        user: attemptUser,
        generation: ctx.generation,
      ))
          .content;
      final parsed = _parse(raw, expected: n);
      if (parsed.length >= 2) {
        return parsed.take(n).toList(growable: false);
      }
      lastError = '需要至少 2 条 choices';
      attemptUser = '$user\n\n上次无法使用：$lastError\n只输出合法 JSON。';
    }
    return const [];
  }

  static List<String> _parse(String raw, {required int expected}) {
    final decoded = decodeJsonCandidate(raw);
    final out = <String>[];
    if (decoded is Map) {
      final list = decoded['choices'];
      if (list is List) {
        for (final item in list) {
          final s = '$item'.trim();
          if (s.isEmpty) continue;
          if (!out.contains(s)) out.add(s);
        }
      }
    }
    if (out.isEmpty) {
      for (final line in raw.split('\n')) {
        final s = line
            .replaceFirst(RegExp(r'^[\s\-\*\d\.\)\]】]+'), '')
            .trim();
        if (s.isEmpty || s.startsWith('{')) continue;
        if (!out.contains(s)) out.add(s);
        if (out.length >= expected) break;
      }
    }
    return out;
  }
}
