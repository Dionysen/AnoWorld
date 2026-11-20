import 'dart:convert';

import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

/// One choice that still needs a post-choice beat grown on the story tree.
class BridgeBranchPrefetchRequest {
  const BridgeBranchPrefetchRequest({
    required this.choice,
    required this.targetNodeId,
  });

  final Choice choice;

  /// Station the next beat should belong to (stay → current; node → dest).
  final String targetNodeId;
}

/// Result row: [choiceId] maps to a generated [beat] (may be missing if parse failed).
class BridgeBranchPrefetchResult {
  const BridgeBranchPrefetchResult({
    required this.choiceId,
    this.beat,
  });

  final String choiceId;
  final Beat? beat;
}

/// One model call that writes up to [BridgeSession.maxChoicesPerBeat] branch beats.
class BridgeBranchPrefetchAction {
  BridgeBranchPrefetchAction({
    required AiTextClient textClient,
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final int maxFormatRetries;

  Future<List<BridgeBranchPrefetchResult>> generate({
    required AiPromptContext ctx,
    required Project project,
    required String sourceNodeId,
    required BridgeSession session,
    required List<BridgeBranchPrefetchRequest> branches,
    PlotElementCatalog? plotCatalog,
    List<String> userAliases = const <String>[],
    int minLines = 1,
  }) async {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final limited = branches.take(BridgeSession.maxChoicesPerBeat).toList();
    if (limited.isEmpty) return const [];

    final source = project.main.nodeById(sourceNodeId);
    if (source == null) {
      throw AiTextException('当前情节站不存在');
    }

    AppLog.instance.info('分支预写 ${limited.length} 路', tag: 'play.vn');

    final branchLines = <String>[];
    for (final b in limited) {
      final dest = project.main.nodeById(b.targetNodeId);
      final stay = b.choice.target.type == TransitionType.beat;
      final exits = project.main.edges
          .where((e) => e.from == b.targetNodeId)
          .map((e) {
        final to = project.main.nodeById(e.to);
        return '${e.to}:${to?.title ?? e.to}';
      }).join(', ');
      branchLines.add(
        '- choiceId:${b.choice.id} 文案:${b.choice.text} '
        '${stay ? '继续本站' : '前往站'} id:${b.targetNodeId} '
        '标题:${dest?.title ?? b.targetNodeId} '
        '目标:${dest?.synopsis ?? ''} '
        '合法下一站:[$exits]',
      );
    }

    final task = '''你是视觉小说演出助手。只输出 JSON，不要 markdown。
为下面每一条选项各写「选中后立刻播放」的一小段对白（一拍）。
输出格式：{"branches":[{"choiceId":"与输入一致","beat":{"location":"地点","lines":[{"speaker":"角色名或旁白或玩家称呼","text":"纯正文"}],"choices":[{"text":"...","target":{...}}]}}]}
规则：
- 每个 choiceId 恰好一条；不要发明未列出的 choiceId。
- text 只写正文，禁止「名字：」前缀。
- 角色开口用角色列表里的名字；玩家用玩家称呼；叙述用「旁白」。
- 每拍 choices 最多 ${BridgeSession.maxChoicesPerBeat} 个。
- 继续本站用 {"type":"beat","beatId":"$kBridgeStayBeatId"}；换站只能用该路「合法下一站」里的 nodeId，或 {"type":"end"}。
- 禁止发明情节站 id。''';

    final system = ctx.assembleSystem(
      project: project,
      plotCatalog: plotCatalog,
      taskSuffix: task,
    );
    final user = '''
当前站：${source.title}
本站目标：${source.synopsis ?? ''}
设定摘要：${project.worldBook.combinedText}
角色：${project.cast.map((c) => c.name).join('、')}
玩家称呼：${userAliases.where((a) => a.trim().isNotEmpty).join('、')}
区间摘要：${session.summary}
请为下列选项各写选中后的下一拍：
${branchLines.join('\n')}''';

    String? lastError;
    var attemptUser = user;
    Map<String, dynamic>? decodedBranches;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      final raw = (await _text.complete(
        endpoint: endpoint,
        system: system,
        user: attemptUser,
        generation: ctx.generation,
      ))
          .content;
      try {
        final decoded = decodeJsonCandidate(raw);
        if (decoded is! Map) {
          throw const BridgeMapException('不是有效 JSON');
        }
        final map = Map<String, dynamic>.from(decoded);
        final list = map['branches'];
        if (list is! List) {
          throw const BridgeMapException('缺少 branches 数组');
        }
        decodedBranches = map;
        break;
      } on BridgeMapException catch (error) {
        lastError = error.message;
        if (attempt >= maxFormatRetries) break;
        attemptUser = '$user\n\n上次无法使用：$lastError\n只输出合法 JSON。';
      }
    }
    if (decodedBranches == null) {
      AppLog.instance.warning(
        '分支批写失败：${lastError ?? '无结果'}',
        tag: 'play.vn',
      );
      throw AiTextException(lastError ?? '分支预写失败，请重试');
    }

    final byChoice = <String, Map<String, dynamic>>{};
    final rawList = decodedBranches['branches'];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final id = '${row['choiceId'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        final beatRaw = row['beat'];
        if (beatRaw is Map) {
          byChoice[id] = Map<String, dynamic>.from(beatRaw);
        }
      }
    }

    final results = <BridgeBranchPrefetchResult>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var ok = 0;
    for (var i = 0; i < limited.length; i++) {
      final b = limited[i];
      final beatMap = byChoice[b.choice.id];
      if (beatMap == null) {
        results.add(BridgeBranchPrefetchResult(choiceId: b.choice.id));
        continue;
      }
      final destNode = b.targetNodeId;
      final exits = project.main.edges
          .where((e) => e.from == destNode)
          .map((e) => e.to)
          .toSet();
      final openMode = exits.isEmpty;
      try {
        final beat = BridgeGenerateAction.parseBeatJson(
          jsonEncode(beatMap),
          project: project,
          nodeId: destNode,
          // Short unique id — never nest choiceId (ids stay readable in logs).
          beatId: 'bridge_${destNode}_$stamp$i',
          legalNodeIds: exits,
          forceConverge: false,
          openMode: openMode,
          userAliases: userAliases,
        );
        if (minLines > 1 && beat.lines.length < minLines) {
          AppLog.instance.warning(
            '分支拍句数不足：${beat.lines.length}/$minLines',
            tag: 'play.vn',
          );
        }
        results.add(
          BridgeBranchPrefetchResult(choiceId: b.choice.id, beat: beat),
        );
        ok++;
      } on BridgeMapException catch (error) {
        AppLog.instance.warning(
          '分支拍解析失败：${error.message}',
          tag: 'play.vn',
        );
        results.add(BridgeBranchPrefetchResult(choiceId: b.choice.id));
      }
    }

    if (ok < limited.length) {
      AppLog.instance.warning(
        '分支预写部分成功 $ok/${limited.length}',
        tag: 'play.vn',
      );
    }
    return results;
  }
}
