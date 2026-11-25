import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_stream_parser.dart';
import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

/// Sentinel beat id for "stay in interval / generate again".
const String kBridgeStayBeatId = '__stay__';

/// One event while a beat streams in.
sealed class BridgeBeatEvent {
  const BridgeBeatEvent();
}

/// A dialogue line that just became readable on the stage.
class BridgeBeatLineEvent extends BridgeBeatEvent {
  const BridgeBeatLineEvent({required this.line, this.location});

  final DialogueLine line;

  /// Scene location text, once the model has written it.
  final String? location;
}

/// The whole beat is final (choices, scene, authoritative lines).
class BridgeBeatDoneEvent extends BridgeBeatEvent {
  const BridgeBeatDoneEvent(this.beat);

  final Beat beat;
}

/// Prompt and request fields shared by buffered and streamed generation.
class _BridgeRequest {
  const _BridgeRequest({
    required this.endpoint,
    required this.system,
    required this.user,
    required this.project,
    required this.nodeId,
    required this.beatId,
    required this.legalNodeIds,
    required this.forceConverge,
    required this.openMode,
    required this.role,
    required this.maxChoices,
    required this.generation,
  });

  final AiTextEndpoint endpoint;
  final String system;
  final String user;
  final Project project;
  final String nodeId;
  final String beatId;
  final Set<String> legalNodeIds;
  final bool forceConverge;
  final bool openMode;
  final PlayRole role;
  final int maxChoices;
  final GenerationPreset? generation;
}

/// Generates one bridge Beat for the current main node interval.
class BridgeGenerateAction {
  BridgeGenerateAction({
    required AiTextClient textClient,
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final int maxFormatRetries;

  Future<Beat> generate({
    required AiPromptContext ctx,
    required Project project,
    required String nodeId,
    required BridgeSession session,
    PlotElementCatalog? plotCatalog,
    int maxBeats = BridgeSession.defaultMaxBeats,
    PlayRole role = PlayRole.none,
    int minLines = 1,
    int maxChoices = AiSettings.defaultMaxInStationChoices,
  }) async {
    final request = _prepare(
      ctx: ctx,
      project: project,
      nodeId: nodeId,
      session: session,
      plotCatalog: plotCatalog,
      maxBeats: maxBeats,
      role: role,
      minLines: minLines,
      maxChoices: maxChoices,
    );
    final user = request.user;
    String? lastError;
    var attemptUser = user;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      final raw = (await _text.complete(
        endpoint: request.endpoint,
        system: request.system,
        user: attemptUser,
        generation: request.generation,
      ))
          .content;
      try {
        final beat = parseBeatJson(
          raw,
          project: project,
          nodeId: nodeId,
          beatId: request.beatId,
          legalNodeIds: request.legalNodeIds,
          forceConverge: request.forceConverge,
          openMode: request.openMode,
          role: role,
          maxChoices: request.maxChoices,
        );
        if (beat.lines.length >= minLines) return beat;
        lastError = '这次只写了 ${beat.lines.length} 句，至少要 $minLines 句';
        if (attempt >= maxFormatRetries) {
          AppLog.instance.warning(
            '本拍句数不足，按当前结果继续：${beat.lines.length}/$minLines 句',
            tag: 'play.vn',
          );
          return beat;
        }
        AppLog.instance.info(
          '本拍句数不足，重试中：${beat.lines.length}/$minLines 句',
          tag: 'play.vn',
        );
        attemptUser = '$user\n\n上次太短了：$lastError\n请补到至少 $minLines 句再输出。';
      } on BridgeMapException catch (error) {
        lastError = error.message;
        if (attempt >= maxFormatRetries) break;
        attemptUser = '$user\n\n上次无法使用：$lastError\n只输出合法 JSON。';
      }
    }
    throw AiTextException(lastError ?? '这一段生成失败，请重试');
  }

  /// Same beat as [generate], delivered while the model writes it.
  ///
  /// Emits every `lines[]` row as soon as its JSON object closes, then the
  /// authoritative [Beat]. Falls back to one whole beat when the client
  /// cannot stream. Errors surface as the usual [AiTextException]; lines that
  /// already went out stay on screen.
  Stream<BridgeBeatEvent> streamGenerate({
    required AiPromptContext ctx,
    required Project project,
    required String nodeId,
    required BridgeSession session,
    PlotElementCatalog? plotCatalog,
    int maxBeats = BridgeSession.defaultMaxBeats,
    PlayRole role = PlayRole.none,
    int minLines = 1,
    int maxChoices = AiSettings.defaultMaxInStationChoices,
  }) async* {
    final request = _prepare(
      ctx: ctx,
      project: project,
      nodeId: nodeId,
      session: session,
      plotCatalog: plotCatalog,
      maxBeats: maxBeats,
      role: role,
      minLines: minLines,
      maxChoices: maxChoices,
    );
    final streaming =
        _text is AiTextStreamClient ? _text as AiTextStreamClient : null;
    if (streaming == null) {
      final beat = await generate(
        ctx: ctx,
        project: project,
        nodeId: nodeId,
        session: session,
        plotCatalog: plotCatalog,
        maxBeats: maxBeats,
        role: role,
        minLines: minLines,
        maxChoices: maxChoices,
      );
      yield BridgeBeatDoneEvent(beat);
      return;
    }

    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: request.beatId,
      role: role,
    );
    final raw = StringBuffer();
    await for (final chunk in streaming.streamText(
      endpoint: request.endpoint,
      system: request.system,
      user: request.user,
      generation: request.generation,
    )) {
      if (chunk.content.isEmpty) continue;
      raw.write(chunk.content);
      for (final line in parser.add(chunk.content)) {
        yield BridgeBeatLineEvent(line: line, location: parser.location);
      }
    }

    final Beat beat;
    try {
      beat = parseBeatJson(
        raw.toString(),
        project: project,
        nodeId: nodeId,
        beatId: request.beatId,
        legalNodeIds: request.legalNodeIds,
        forceConverge: request.forceConverge,
        openMode: request.openMode,
        role: role,
        maxChoices: request.maxChoices,
      );
      if (beat.lines.length < minLines) {
        AppLog.instance.warning(
          '流式本拍句数不足，按当前结果继续：${beat.lines.length}/$minLines 句',
          tag: 'play.vn',
        );
      }
      yield BridgeBeatDoneEvent(beat);
    } on BridgeMapException catch (error) {
      // The stream was already shown; finish with the lines we have instead
      // of throwing the whole beat away.
      AppLog.instance.warning(
        '流式本拍收尾失败，按已出现的句子继续：${error.message}',
        tag: 'play.vn',
      );
      yield BridgeBeatDoneEvent(
        _partialBeat(
          request: request,
          project: project,
          parser: parser,
        ),
      );
    }
  }

  /// Beat built from the lines that already reached the player.
  static Beat _partialBeat({
    required _BridgeRequest request,
    required Project project,
    required BridgeBeatStreamParser parser,
  }) {
    final lines = parser.lines;
    return Beat(
      id: request.beatId,
      nodeId: request.nodeId,
      scene: Scene(locationText: parser.location),
      appearances: const [],
      lines: lines.isEmpty
          ? <DialogueLine>[
              DialogueLine(
                id: '${request.beatId}_l0',
                text: '……',
                kind: DialogueKind.narration,
              ),
            ]
          : lines,
      choices: request.forceConverge
          ? fallbackChoices(project.main, request.nodeId)
          : const <Choice>[],
    );
  }

  /// Prompt + request fields shared by [generate] and [streamGenerate].
  _BridgeRequest _prepare({
    required AiPromptContext ctx,
    required Project project,
    required String nodeId,
    required BridgeSession session,
    PlotElementCatalog? plotCatalog,
    required int maxBeats,
    required PlayRole role,
    required int minLines,
    required int maxChoices,
  }) {
    final endpoint = ctx.endpoint;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final node = project.main.nodeById(nodeId);
    if (node == null) {
      throw AiTextException('当前情节站不存在');
    }

    final choiceCap = AiSettings.clampMaxInStationChoices(maxChoices);
    final exits = project.main.edges
        .where((e) => e.from == nodeId)
        .toList(growable: false);
    final openMode = exits.isEmpty;
    final exitLines = exits.map((e) {
      final to = project.main.nodeById(e.to);
      final title = to?.title ?? e.to;
      final syn = to?.synopsis ?? '';
      final choice =
          e.label?.trim().isNotEmpty == true ? e.label!.trim() : '（无选项标题）';
      final detail = e.detail?.trim().isNotEmpty == true
          ? e.detail!.trim()
          : '（无详细说明）';
      return '- id:${e.to} 下一站:$title 目标:$syn 选项:$choice 说明:$detail';
    }).join('\n');

    // Open interval never force-converges to a next node.
    final nextTurn = session.turnCount + 1;
    final forceConverge = !openMode && nextTurn >= maxBeats;
    final nearConverge = !openMode &&
        !forceConverge &&
        nextTurn >= ((maxBeats * 7) / 10).ceil();
    final task = _taskBlock(
      forceConverge: forceConverge,
      openMode: openMode,
      minLines: minLines,
      maxChoices: choiceCap,
      nearConverge: nearConverge,
    );
    final nextStationBlock = openMode
        ? '本站没有固定下一站：按设定与角色自由续写，不要发明情节站 id。'
        : '合法下一站（只能跳到这些 id，或 end）：\n$exitLines';
    final paceHint = openMode
        ? ''
        : (forceConverge
            ? '本拍必须收束到下一站或结束，对白要自然收束，不要突然跳切。\n'
            : (nearConverge
                ? '已接近本站尾声：对白可自然埋下前往下一站的动机。\n'
                : ''));
    String blockFor(String summaryText) => _userBlock(
          node: node,
          project: project,
          role: role,
          nextStationBlock: nextStationBlock,
          summary: summaryText,
          turnCount: session.turnCount,
          maxBeats: maxBeats,
          openMode: openMode,
          paceHint: paceHint,
        );

    final budget = ContextBudget.of(ctx.generation);
    final system = ctx.assemblePlaySystem(
      project: project,
      plotCatalog: plotCatalog,
      recentText: <String>[
        node.title,
        node.synopsis ?? '',
        session.summary,
        for (final beat in session.generatedBeats.reversed.take(2))
          for (final line in beat.lines) line.text,
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

    return _BridgeRequest(
      endpoint: endpoint,
      system: system,
      user: blockFor(summaryText),
      project: project,
      nodeId: nodeId,
      beatId: 'bridge_${nodeId}_${session.turnCount + 1}',
      legalNodeIds: exits.map((e) => e.to).toSet(),
      forceConverge: forceConverge,
      openMode: openMode,
      role: role,
      maxChoices: choiceCap,
      generation: ctx.generation,
    );
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
      // Open interval: keep playing or soft-end.
      return [
        const Choice(
          id: 'fb_continue',
          text: '继续',
          target: Transition(
            type: TransitionType.beat,
            beatId: kBridgeStayBeatId,
          ),
        ),
        const Choice(
          id: 'fb_end',
          text: '告一段落',
          target: Transition(type: TransitionType.end),
        ),
      ];
    }
    return capChoices([
      for (var i = 0; i < outs.length; i++)
        Choice(
          id: 'fb_$i',
          text: _fallbackChoiceText(main, outs[i]),
          target: Transition.toNode(outs[i].to),
        ),
    ]);
  }

  /// Keep at most [maxChoices], preferring stay then exits.
  static List<Choice> capChoices(
    List<Choice> choices, {
    int maxChoices = AiSettings.defaultMaxInStationChoices,
  }) {
    final max = AiSettings.clampMaxInStationChoices(maxChoices);
    if (choices.length <= max) {
      return List<Choice>.unmodifiable(choices);
    }
    int rank(Choice c) => switch (c.target.type) {
          TransitionType.beat => 0,
          TransitionType.node => 1,
          TransitionType.end => 2,
        };
    final ranked = [...choices]..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        return choices.indexOf(a).compareTo(choices.indexOf(b));
      });
    return List<Choice>.unmodifiable(ranked.take(max));
  }

  static String _fallbackChoiceText(MainStory main, StoryEdge edge) {
    final label = edge.label?.trim();
    if (label != null && label.isNotEmpty) return label;
    final dest = main.nodeById(edge.to)?.title ?? edge.to;
    return '动身去$dest';
  }

  static String _userBlock({
    required StoryNode node,
    required Project project,
    required PlayRole role,
    required String nextStationBlock,
    required String summary,
    required int turnCount,
    required int maxBeats,
    required bool openMode,
    required String paceHint,
  }) {
    final castLine = project.cast.map((c) {
      final aliases = c.aliases.where((a) => a.trim().isNotEmpty).toList();
      return aliases.isEmpty ? c.name : '${c.name}（别名：${aliases.join('/')}）';
    }).join('、');
    final player = role.playerIn(project);
    final focus = role.focusIn(project);
    return '''
当前站：${node.title}
本站目标：${node.synopsis ?? ''}
角色：${castLine.isEmpty ? '（无）' : castLine}
玩家扮演：${player?.name ?? '（未指定）'}（旁白一律用「你」指代此人）${focus == null ? '' : '\n焦点角色：${focus.name}'}
$nextStationBlock
区间摘要：$summary
已生成拍数：$turnCount/${openMode ? '∞' : maxBeats}
$paceHint请以「你」为视角生成本站下一小段；选项须是你当下可做的言行。''';
  }

  static String _taskBlock({
    required bool forceConverge,
    required bool openMode,
    required int minLines,
    required int maxChoices,
    required bool nearConverge,
  }) {
    final minLineRule = minLines > 1
        ? '- lines 至少 $minLines 句（对白与叙述合计），每句单独一条。'
        : '';
    final choiceCap =
        '需要分叉时：尽量给出刚好 $maxChoices 个互不重复的选项；剧情撑不住时可以更少，绝不可超过 $maxChoices。不需要分叉时 choices 用空数组。';
    final sharedHead = '''你是视觉小说演出助手。只输出 JSON，不要 markdown。
输出格式：{"location":"地点","lines":[{"speaker":"角色名","text":"纯正文"}],"choices":[{"text":"选项文案","target":{...}}]}
规则：
- speaker 只能是「角色」列表里的名字或别名、玩家扮演角色的名字，或「旁白」；不要发明列表外的名字。
- 玩家开口：speaker 用玩家扮演角色的名字；text 只写他说出口的话。
- 环境/动作/心理叙述：speaker 用「旁白」。
- text 只写对白/叙述正文，禁止「瑞希：」「User：」这类前缀。
- 第二人称：凡旁白叙述里指代玩家扮演的角色，一律用「你」，禁止用其姓名或「他/她」指代玩家。示例：「你来到这家餐馆，看到墙上竟也有一模一样的画。」
- 全程玩家视角：写「你」所见所闻所感；旁白只能写你能感知的环境与动作，禁止上帝全知（不在场的密谋、他人内心、远处同时发生的事）。
- 若你需要得知本不该知道的事，必须安排亲历获知（跟踪、潜入、到场目击等），并写出占用时间/耽误正事等代价；禁止无代价突然知道。
- 选项 text：必须是「你」当下可做的行动或可说的话（可带引号对白），禁止客观事件、场景跳切或结果说明。好例：「推门进去看看」「『这是怎么回事？』」；坏例：「天黑了」「来到大厅」「时间快进到第二天」。
$minLineRule
- $choiceCap''';
    if (openMode) {
      return '''$sharedHead
本站开放续写：不需要分叉时 choices 用空数组（玩家点屏续写）；需要分叉时尽量给满 $maxChoices 个选项（继续用 {"type":"beat","beatId":"$kBridgeStayBeatId"}，或 {"type":"end"}），可少不可多；选项文案仍须是你的言行。
禁止发明情节站 nodeId。''';
    }
    if (forceConverge) {
      return '''$sharedHead
本拍必须收束离站：尽量给满 $maxChoices 个 choices（至少 1 个），每个 target 只能是 {"type":"node","nodeId":"合法id"} 或 {"type":"end"}（不同选项须导向不同世界线）。禁止 stay。对白要自然收束；选项文案写成你决定离开/前往的言行，不要写成「场景已切换」。
禁止发明不在合法下一站列表里的 nodeId。''';
    }
    final nearHint = nearConverge
        ? '已接近本站尾声：对白可自然埋下你想离开或前往下一处的动机。'
        : '';
    return '''$sharedHead
本拍是站内过程：不需要分叉时 choices 用空数组；需要分叉时尽量给满 $maxChoices 个选项（继续用 stay；提前离站须用合法 nodeId，且不同离站选项须导向不同世界线），可少不可多。$nearHint
禁止发明不在合法下一站列表里的 nodeId。''';
  }

  /// Shared Beat JSON mapper (also used by branch batch prefetch).
  static Beat parseBeatJson(
    String raw, {
    required Project project,
    required String nodeId,
    required String beatId,
    required Set<String> legalNodeIds,
    required bool forceConverge,
    required bool openMode,
    PlayRole role = PlayRole.none,
    int maxChoices = AiSettings.defaultMaxInStationChoices,
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
        final line = dialogueLineFromRow(
          Map<String, dynamic>.from(item),
          index: i,
          beatId: beatId,
          project: project,
          role: role,
        );
        if (line == null) continue;
        lines.add(line);
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
          if (openMode) continue;
          final id = '${targetMap['nodeId'] ?? ''}'.trim();
          if (!legalNodeIds.contains(id)) {
            continue;
          }
          target = Transition.toNode(id);
        } else if (type == 'beat' && !forceConverge) {
          // Stay sentinel — runtime maps missing beat id to needsBridge.
          target = Transition.toBeat(kBridgeStayBeatId);
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

    final capped = capChoices(choices, maxChoices: maxChoices);

    return Beat(
      id: beatId,
      nodeId: nodeId,
      scene: Scene(
        locationText: '${map['location'] ?? ''}'.trim().isEmpty
            ? null
            : '${map['location']}'.trim(),
      ),
      appearances: const [],
      lines: lines,
      choices: capped,
    );
  }
}

class BridgeMapException implements Exception {
  const BridgeMapException(this.message);
  final String message;
  @override
  String toString() => message;
}
