import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_stream_parser.dart';
import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
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
    required this.userAliases,
    required this.allowInStationChoices,
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
  final List<String> userAliases;
  final bool allowInStationChoices;
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
    List<String> userAliases = const <String>[],
    int minLines = 1,
    InStationChoiceFrequency inStationChoiceFrequency =
        InStationChoiceFrequency.rare,
  }) async {
    final request = _prepare(
      ctx: ctx,
      project: project,
      nodeId: nodeId,
      session: session,
      plotCatalog: plotCatalog,
      maxBeats: maxBeats,
      userAliases: userAliases,
      minLines: minLines,
      inStationChoiceFrequency: inStationChoiceFrequency,
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
          userAliases: userAliases,
          allowInStationChoices: request.allowInStationChoices,
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
    List<String> userAliases = const <String>[],
    int minLines = 1,
    InStationChoiceFrequency inStationChoiceFrequency =
        InStationChoiceFrequency.rare,
  }) async* {
    final request = _prepare(
      ctx: ctx,
      project: project,
      nodeId: nodeId,
      session: session,
      plotCatalog: plotCatalog,
      maxBeats: maxBeats,
      userAliases: userAliases,
      minLines: minLines,
      inStationChoiceFrequency: inStationChoiceFrequency,
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
        userAliases: userAliases,
        minLines: minLines,
        inStationChoiceFrequency: inStationChoiceFrequency,
      );
      yield BridgeBeatDoneEvent(beat);
      return;
    }

    final parser = BridgeBeatStreamParser(
      project: project,
      beatId: request.beatId,
      userAliases: userAliases,
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
        userAliases: userAliases,
        allowInStationChoices: request.allowInStationChoices,
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
    required List<String> userAliases,
    required int minLines,
    required InStationChoiceFrequency inStationChoiceFrequency,
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
    final allowInStationChoices = !forceConverge &&
        inStationChoiceFrequency.allowsChoicesAtTurn(session.turnCount);
    final task = _taskBlock(
      forceConverge: forceConverge,
      openMode: openMode,
      minLines: minLines,
      allowInStationChoices: allowInStationChoices,
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
          userAliases: userAliases,
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
      userAliases: userAliases,
      allowInStationChoices: allowInStationChoices,
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

  /// Keep at most [BridgeSession.maxChoicesPerBeat], preferring stay then exits.
  static List<Choice> capChoices(List<Choice> choices) {
    const max = BridgeSession.maxChoicesPerBeat;
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
    return '前往：$dest';
  }

  static String _userBlock({
    required StoryNode node,
    required Project project,
    required List<String> userAliases,
    required String nextStationBlock,
    required String summary,
    required int turnCount,
    required int maxBeats,
    required bool openMode,
    required String paceHint,
  }) {
    return '''
当前站：${node.title}
本站目标：${node.synopsis ?? ''}
角色：${project.cast.map((c) => c.name).join('、')}
玩家称呼：${userAliases.where((a) => a.trim().isNotEmpty).join('、')}
$nextStationBlock
区间摘要：$summary
已生成拍数：$turnCount/${openMode ? '∞' : maxBeats}
$paceHint请生成本站下一小段对白。''';
  }

  static String _taskBlock({
    required bool forceConverge,
    required bool openMode,
    required int minLines,
    required bool allowInStationChoices,
    required bool nearConverge,
  }) {
    final minLineRule = minLines > 1
        ? '- lines 至少 $minLines 句（对白与叙述合计），每句单独一条。'
        : '';
    const choiceCap =
        'choices 最多 ${BridgeSession.maxChoicesPerBeat} 个。';
    final sharedHead = '''你是视觉小说演出助手。只输出 JSON，不要 markdown。
输出格式：{"location":"地点","lines":[{"speaker":"角色名或旁白或玩家称呼","text":"纯正文"}],"choices":[...]}
规则：
- text 只写对白/叙述正文，禁止「瑞希：」「User：」这类前缀。
- 全程以主角（玩家）视角：写其所见所闻所感；旁白只能写主角能感知的环境与动作，禁止上帝全知（不在场的密谋、他人内心、远处同时发生的事）。
- 若主角需要得知本不该知道的事，必须安排亲历获知（跟踪、潜入、到场目击等），并写出占用时间/耽误正事等代价；禁止无代价突然知道。
- 角色开口：speaker 必须是角色列表里的名字，不能写成旁白。
- 玩家开口：speaker 用玩家称呼（或故事里对玩家的叫法，如「老公」）。
- 环境/动作叙述：speaker 用「旁白」（仍须主角可感知）。
$minLineRule
- $choiceCap''';
    if (openMode) {
      final choiceRule = allowInStationChoices
          ? '本站开放续写：本拍可给至多 ${BridgeSession.maxChoicesPerBeat} 个选项（继续用 {"type":"beat","beatId":"$kBridgeStayBeatId"}，或 {"type":"end"}）；也可 choices 为空数组，由玩家点屏续写。'
          : '本站开放续写：本拍 choices 必须是空数组 []，不要给选项；玩家点屏幕续写下一段。禁止发明情节站 nodeId。';
      return '''$sharedHead
$choiceRule
禁止发明情节站 nodeId。''';
    }
    if (forceConverge) {
      return '''$sharedHead
本拍必须收束离站：给 1～${BridgeSession.maxChoicesPerBeat} 个 choices，每个 target 只能是 {"type":"node","nodeId":"合法id"} 或 {"type":"end"}（不同选项须导向不同世界线）。禁止 stay。对白要自然收束。
禁止发明不在合法下一站列表里的 nodeId。''';
    }
    final nearHint = nearConverge
        ? '已接近本站尾声：对白可自然埋下前往下一站的动机。'
        : '';
    final choiceRule = allowInStationChoices
        ? '本拍是站内过程：可给空 choices，或至多 ${BridgeSession.maxChoicesPerBeat} 个选项（继续用 stay；提前离站须用合法 nodeId，且不同离站选项须导向不同世界线）。$nearHint'
        : '本拍是站内过程：choices 必须是空数组 []，不要给选项；玩家点屏幕续写。$nearHint';
    return '''$sharedHead
$choiceRule
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
    List<String> userAliases = const <String>[],
    bool allowInStationChoices = true,
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
          userAliases: userAliases,
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
    // In-station / open process beats may be choice-free (tap to continue).
    if (!forceConverge && !allowInStationChoices) {
      choices.clear();
    }

    final capped = capChoices(choices);

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
