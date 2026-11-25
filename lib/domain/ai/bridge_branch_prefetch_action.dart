import 'dart:convert';

import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
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

/// One model call that writes up to [maxChoices] branch beats.
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
    PlayRole role = PlayRole.none,
    int minLines = 1,
    int maxChoices = AiSettings.defaultMaxInStationChoices,
  }) async {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final choiceCap = AiSettings.clampMaxInStationChoices(maxChoices);
    final limited = branches.take(choiceCap).toList();
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

    final minLineRule = minLines > 1
        ? '- 每拍 lines 至少 $minLines 句，每句单独一条。'
        : '';
    final task = '''你是视觉小说演出助手。只输出 JSON，不要 markdown。
为下面每一条选项各写「选中后立刻播放」的一小段对白（一拍）。
输出格式：{"branches":[{"choiceId":"与输入一致","beat":{"location":"地点","lines":[{"speaker":"角色名","text":"纯正文"}],"choices":[]}}]}
规则：
- 每个 choiceId 恰好一条；不要发明未列出的 choiceId。
- text 只写正文，禁止「名字：」前缀。
- speaker 只能是「角色」列表里的名字或别名、玩家扮演角色的名字，或「旁白」；不要发明列表外的名字。
- 玩家开口：speaker 用玩家扮演角色的名字；叙述用「旁白」。
- 旁白里指代玩家扮演的角色一律用「你」，禁止用其姓名或「他/她」。
- 接着写「你」做出该选项后立刻发生的所见所感，不要跳场景总结。
$minLineRule
- 这些「选中后」的拍默认是站内过程：choices 用空数组 []，不要给选项（玩家点屏续写）。
- 每拍 choices 若非空则尽量给满 $choiceCap 个，可少不可多；若有选项，文案仍须是「你」的言行，禁止客观跳场。
- 禁止发明情节站 id。''';

    final budget = ContextBudget.of(ctx.generation);
    final branchBlock = branchLines.join('\n');
    final castLine = project.cast.map((c) {
      final aliases = c.aliases.where((a) => a.trim().isNotEmpty).toList();
      return aliases.isEmpty ? c.name : '${c.name}（别名：${aliases.join('/')}）';
    }).join('、');
    final player = role.playerIn(project);
    final focus = role.focusIn(project);
    String blockFor(String summaryText) => '''
当前站：${source.title}
本站目标：${source.synopsis ?? ''}
角色：${castLine.isEmpty ? '（无）' : castLine}
玩家扮演：${player?.name ?? '（未指定）'}（旁白一律用「你」指代此人）${focus == null ? '' : '\n焦点角色：${focus.name}'}
区间摘要：$summaryText
请以「你」为视角，为下列选项各写选中后立刻发生的下一拍：
$branchBlock''';

    final system = ctx.assemblePlaySystem(
      project: project,
      plotCatalog: plotCatalog,
      recentText: <String>[
        source.title,
        source.synopsis ?? '',
        session.summary,
        for (final beat in session.generatedBeats.reversed.take(2))
          for (final line in beat.lines) line.text,
        for (final branch in limited) branch.choice.text,
      ],
      playRole: role,
      taskSuffix: task,
      budget: budget,
      reservedTokens: budget.estimate(blockFor('')),
    );
    final summaryTokens = budget.remaining(
      budget.estimate(system) + budget.estimate(blockFor('')),
    );
    final summaryText = budget.keepTail(
      session.summary,
      tokens: summaryTokens,
    );
    if (summaryText.length < session.summary.length) {
      AppLog.instance.info('区间摘要超出预算，只带最新部分', tag: 'play.vn');
    }
    final user = blockFor(summaryText);

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
          role: role,
          maxChoices: choiceCap,
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
