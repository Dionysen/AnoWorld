import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/preset.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

/// Generates one bridge Beat for the current main node interval.
class BridgeGenerateAction {
  BridgeGenerateAction({
    required AiTextClient textClient,
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final int maxFormatRetries;

  Future<Beat> generate({
    required AiTextEndpoint endpoint,
    required Project project,
    required String nodeId,
    required BridgeSession session,
    int maxBeats = BridgeSession.defaultMaxBeats,
  }) async {
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final node = project.main.nodeById(nodeId);
    if (node == null) {
      throw AiTextException('当前情节站不存在');
    }

    final exits = project.main.edges
        .where((e) => e.from == nodeId)
        .toList(growable: false);
    final exitLines = exits.map((e) {
      final to = project.main.nodeById(e.to);
      final title = to?.title ?? e.to;
      final syn = to?.synopsis ?? '';
      return '- id:${e.to} 标题:$title 目标:$syn';
    }).join('\n');

    final forceConverge = session.turnCount + 1 >= maxBeats;
    final preset = project.activePreset;
    final system = _system(preset, forceConverge: forceConverge);
    final user = '''
当前站：${node.title}
本站目标：${node.synopsis ?? ''}
设定摘要：${project.background.combinedText}
角色：${project.cast.map((c) => c.name).join('、')}
合法下一站（只能跳到这些 id，或 end）：
$exitLines
区间摘要：${session.summary}
已生成拍数：${session.turnCount}/$maxBeats
请生成本站下一小段对白。''';

    String? lastError;
    var attemptUser = user;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      final raw = await _text.complete(
        endpoint: endpoint,
        system: system,
        user: attemptUser,
      );
      try {
        return _parseBeat(
          raw,
          nodeId: nodeId,
          beatId: 'bridge_${nodeId}_${session.turnCount + 1}',
          legalNodeIds: exits.map((e) => e.to).toSet(),
          forceConverge: forceConverge,
        );
      } on BridgeMapException catch (error) {
        lastError = error.message;
        if (attempt >= maxFormatRetries) break;
        attemptUser = '$user\n\n上次无法使用：$lastError\n只输出合法 JSON。';
      }
    }
    throw AiTextException(lastError ?? '这一段生成失败，请重试');
  }

  /// Guaranteed exit choices when AI is unavailable.
  static List<Choice> fallbackChoices(MainStory main, String nodeId) {
    final outs = main.edges.where((e) => e.from == nodeId).toList();
    if (outs.isEmpty) {
      final node = main.nodeById(nodeId);
      if (node != null && node.tags.contains('ending')) {
        return [
          const Choice(
            id: 'fb_end',
            text: '结束',
            target: Transition(type: TransitionType.end),
          ),
        ];
      }
      return [
        const Choice(
          id: 'fb_end',
          text: '结束',
          target: Transition(type: TransitionType.end),
        ),
      ];
    }
    return [
      for (var i = 0; i < outs.length; i++)
        Choice(
          id: 'fb_$i',
          text: '前往：${main.nodeById(outs[i].to)?.title ?? outs[i].to}',
          target: Transition.toNode(outs[i].to),
        ),
    ];
  }

  static String _system(Preset preset, {required bool forceConverge}) {
    final converge = forceConverge
        ? '必须给 1～3 个 choices，且每个 target 只能是 {"type":"node","nodeId":"合法id"} 或 {"type":"end"}。禁止 stay。'
        : '可给过程选项；若继续本站用 {"type":"beat","beatId":"__stay__"}；导向下一站必须用合法 nodeId。';
    return '''你是视觉小说演出助手。只输出 JSON，不要 markdown。
文风：${preset.styleNotes}
输出格式：{"location":"地点","lines":[{"speaker":"角色名或旁白","text":"..."}],"choices":[{"text":"...","target":{...}}]}
$converge
禁止发明不在合法下一站列表里的 nodeId。''';
  }

  static Beat _parseBeat(
    String raw, {
    required String nodeId,
    required String beatId,
    required Set<String> legalNodeIds,
    required bool forceConverge,
  }) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const BridgeMapException('不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final linesRaw = map['lines'];
    final lines = <DialogueLine>[];
    if (linesRaw is List) {
      for (var i = 0; i < linesRaw.length; i++) {
        final item = linesRaw[i];
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final text = '${row['text'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        final speaker = '${row['speaker'] ?? ''}'.trim();
        final narration =
            speaker.isEmpty || speaker == '旁白' || speaker == 'narrator';
        lines.add(
          DialogueLine(
            id: '${beatId}_l$i',
            text: narration ? text : '$speaker：$text',
            kind: DialogueKind.narration,
          ),
        );
      }
    }
    if (lines.isEmpty) {
      lines.add(
        DialogueLine(
          id: '${beatId}_l0',
          text: '……',
          kind: DialogueKind.narration,
        ),
      );
    }

    final choices = <Choice>[];
    final choicesRaw = map['choices'];
    if (choicesRaw is List) {
      for (var i = 0; i < choicesRaw.length; i++) {
        final item = choicesRaw[i];
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final text = '${row['text'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        final targetRaw = row['target'];
        if (targetRaw is! Map) continue;
        final targetMap = Map<String, dynamic>.from(targetRaw);
        final type = '${targetMap['type'] ?? ''}';
        Transition? target;
        if (type == 'end') {
          target = Transition.end();
        } else if (type == 'node') {
          final id = '${targetMap['nodeId'] ?? ''}'.trim();
          if (!legalNodeIds.contains(id)) {
            continue;
          }
          target = Transition.toNode(id);
        } else if (type == 'beat' && !forceConverge) {
          // Stay in interval — placeholder; runtime treats as needs another bridge.
          target = Transition.toBeat(beatId);
        }
        if (target == null) continue;
        choices.add(Choice(id: '${beatId}_c$i', text: text, target: target));
      }
    }

    if (forceConverge &&
        choices.every((c) => c.target.type == TransitionType.beat)) {
      throw const BridgeMapException('收敛拍缺少通往下一站的选项');
    }
    if (choices.isEmpty && forceConverge) {
      throw const BridgeMapException('收敛拍没有选项');
    }

    return Beat(
      id: beatId,
      nodeId: nodeId,
      scene: Scene(locationText: '${map['location'] ?? ''}'.trim().isEmpty
          ? null
          : '${map['location']}'.trim()),
      appearances: const [],
      lines: lines,
      choices: choices,
    );
  }
}

class BridgeMapException implements Exception {
  const BridgeMapException(this.message);
  final String message;
  @override
  String toString() => message;
}
