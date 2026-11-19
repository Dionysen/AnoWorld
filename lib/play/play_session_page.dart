import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/chat/tavern_chat_generate_action.dart';
import 'package:anoworld/domain/chat/tavern_reply_choice_action.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/main_runtime.dart';
import 'package:anoworld/domain/runtime/play_history.dart';
import 'package:anoworld/domain/runtime/play_pointer.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_surface.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/play_chat_message.dart';
import 'package:anoworld/play/play_chat_view.dart';
import 'package:anoworld/play/chat_settings_page.dart';
import 'package:anoworld/settings/ai_model_picker.dart';
import 'package:flutter/material.dart';

export 'package:anoworld/domain/runtime/play_view_mode.dart' show PlayViewMode;

/// Play session locked to one [mode] (chosen before open; not switchable here).
///
/// Pass [slotId] to resume an existing save. Omit it (and set [resumeSave] false)
/// to start a **new** slot — e.g. story hub「开始游玩」.
class PlaySessionPage extends StatefulWidget {
  const PlaySessionPage({
    super.key,
    required this.project,
    required this.mode,
    this.slotId,
    this.resumeSave = true,
    this.initialSave,
  });

  final Project project;
  final PlayViewMode mode;

  /// Existing save slot to resume; null means allocate a new id.
  final String? slotId;
  final bool resumeSave;
  final MainSavePointer? initialSave;

  @override
  State<PlaySessionPage> createState() => _PlaySessionPageState();
}

class _PlaySessionPageState extends State<PlaySessionPage> {
  late MainRuntime _runtime;
  late String _slotId;
  BridgeSession? _bridge;
  String? _status;
  bool _bootstrapped = false;

  /// VN AI call in flight (immediate adopt or background prefetch).
  bool _generating = false;
  bool _assistantBusy = false;
  bool _choicesBusy = false;

  /// Prefetched beats for the current station, not yet adopted.
  /// Target depth: [_prefetchTarget] so the player usually has the next
  /// two generations ready while reading the current one.
  final List<Beat> _prefetchQueue = <Beat>[];
  static const int _prefetchTarget = 2;

  /// Bumped to discard in-flight results after restart / node change.
  int _generateEpoch = 0;

  /// After a background prefetch error, wait until the next adopt before retrying.
  bool _prefetchPaused = false;

  /// Tavern chat transcript (chat mode only).
  final List<TavernChatMessage> _chat = <TavernChatMessage>[];
  List<String> _replyChoices = const <String>[];

  /// VN position timeline (back / forward / fast-forward).
  final PlayHistory _history = PlayHistory();
  Timer? _fastForwardTimer;

  Project get _project => widget.project;

  bool get _isChat => widget.mode == PlayViewMode.chat;

  bool get _chatLocked => _assistantBusy || _choicesBusy;

  MainStory get _baseMain =>
      ProjectFactory.ensurePlayableMain(widget.project.main);

  String _newSlotId() => 'save_${DateTime.now().microsecondsSinceEpoch}';

  String get _userLabel {
    final name =
        AppScope.settingsOf(context).activePersona?.name.trim() ?? '';
    return name.isNotEmpty ? name : context.strings.userLabelFallback;
  }

  String get _assistantLabel {
    for (final member in _project.cast) {
      if (member.isProtagonist) return member.name;
    }
    if (_project.cast.isNotEmpty) return _project.cast.first.name;
    return context.strings.castLabelFallback;
  }

  List<PlayChatMessage> get _chatUiMessages {
    final user = _userLabel;
    final assistant = _assistantLabel;
    return [
      for (final m in _chat)
        PlayChatMessage.fromTavern(
          m,
          userLabel: user,
          assistantLabel: assistant,
        ),
    ];
  }

  String _newChatId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _slotId = widget.slotId ?? _newSlotId();
    _runtime = MainRuntime(_baseMain, save: widget.initialSave);
    final resume = widget.resumeSave &&
        widget.slotId != null &&
        widget.initialSave == null;
    if (resume) {
      _loadSlot(widget.slotId!);
    } else if (_isChat) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureChatOpening());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _recordPosition();
        await _persist();
        await _ensureBridge();
      });
    }
  }

  @override
  void dispose() {
    _fastForwardTimer?.cancel();
    _generateEpoch++;
    super.dispose();
  }

  Future<void> _loadSlot(String slotId) async {
    final slot = await AppScope.savesOf(context).load(slotId);
    if (!mounted) return;
    if (slot != null) {
      if (_isChat) {
        _chat
          ..clear()
          ..addAll(slot.chat);
        _replyChoices = List<String>.unmodifiable(slot.replyChoices);
        _runtime = MainRuntime(_baseMain, save: slot.pointer);
        setState(() => _status = null);
      } else {
        var main = _baseMain;
        final bridge = slot.bridge;
        if (bridge != null && bridge.generatedBeats.isNotEmpty) {
          main = _mergeBeats(main, bridge.generatedBeats);
          _bridge = bridge;
        }
        _runtime = MainRuntime(main, save: slot.pointer);
        _history.clear();
        if (slot.history.isEmpty) {
          // Legacy slot: seed the timeline with the restored position.
          _recordPosition();
        } else {
          _history.entries.addAll(slot.history);
          _history.cursor = slot.historyCursor.clamp(
            0,
            slot.history.length - 1,
          );
        }
        setState(() => _status = context.strings.progressLoaded);
      }
    }
    if (_isChat) {
      await _ensureChatOpening();
    } else {
      await _ensureBridge();
    }
  }

  MainStory _mergeBeats(MainStory main, List<Beat> beats) {
    var working = main;
    for (final beat in beats) {
      final node = working.nodeById(beat.nodeId);
      if (node == null) continue;
      final allBeats = [
        ...working.beats.where((b) => b.id != beat.id),
        beat,
      ];
      final ids = node.beatIds.contains(beat.id)
          ? node.beatIds
          : [...node.beatIds, beat.id];
      working = MainStory(
        summary: working.summary,
        startNodeId: working.startNodeId,
        nodes: working.nodes
            .map(
              (n) => n.id == node.id
                  ? StoryNode(
                      id: n.id,
                      title: n.title,
                      synopsis: n.synopsis,
                      beatIds: ids,
                      layout: n.layout,
                      tags: n.tags,
                    )
                  : n,
            )
            .toList(growable: false),
        edges: working.edges,
        beats: allBeats,
      );
    }
    return working;
  }

  bool _isNarration(DialogueLine line) =>
      line.kind == DialogueKind.narration || line.speakerId == null;

  String? _speakerLabel(DialogueLine line) {
    if (_isNarration(line)) return null;
    final member = _project.castById(line.speakerId!);
    return member?.name ?? line.speakerId!;
  }

  List<String> _userAliases() {
    final persona = AppScope.settingsOf(context).activePersona;
    return <String>[
      if (persona != null && persona.name.trim().isNotEmpty) persona.name.trim(),
      'User',
      '玩家',
      '{{user}}',
    ];
  }

  /// Records the runtime cursor as the newest VN progress.
  void _recordPosition() {
    if (_isChat) return;
    _history.record(_runtime.toSave());
  }

  Future<void> _persist() async {
    if (!mounted) return;
    await AppScope.savesOf(context).save(
      slotId: _slotId,
      projectId: widget.project.meta.id,
      pointer: _runtime.toSave(),
      bridge: _isChat ? null : _bridge,
      mode: widget.mode,
      chat: _isChat ? List<TavernChatMessage>.unmodifiable(_chat) : const [],
      replyChoices:
          _isChat ? List<String>.unmodifiable(_replyChoices) : const [],
      history:
          _isChat ? const <MainSavePointer>[] : _history.entries.toList(),
      historyCursor: _isChat ? -1 : _history.cursor,
    );
  }

  void _advance() {
    if (!_runtime.canAdvance) return;
    setState(() {
      _runtime.advance();
      _recordPosition();
    });
    _persist();
    _ensureBridge();
  }

  void _choose(Choice choice) {
    _stopFastForward();
    setState(() {
      _runtime.choose(choice.id);
      _syncBridgeNode();
      _recordPosition();
    });
    _persist();
    _ensureBridge();
  }

  void _goBack() {
    _stopFastForward();
    final target = _history.stepBack();
    if (target == null) return;
    AppLog.instance.info(
      '视觉小说后退到第 ${_history.cursor + 1}/${_history.entries.length} 步',
      tag: 'play.vn',
    );
    _restorePosition(target);
  }

  void _goForward() {
    _stopFastForward();
    final target = _history.stepForward();
    if (target == null) return;
    _restorePosition(target);
  }

  /// Empty buffer and AI still writing the beat the player needs right now.
  bool get _waitingForBeat =>
      _runtime.needsBridge && _prefetchQueue.isEmpty && _generating;

  /// Whether the story can still move past the current point.
  /// Prefetch in the background does not block line advance.
  bool get _canContinueStory {
    if (_runtime.pointer.isEnded) return false;
    if (_runtime.canAdvance) return true;
    if (!_runtime.needsBridge) return false;
    if (_prefetchQueue.isNotEmpty) return true;
    // Waiting on the first beat of an empty buffer: still "can continue" so
    // the forward button stays active and kicks generation, unless already
    // generating with nothing ready.
    return !_generating;
  }

  /// Forward button: replay the next recorded line, or — already at the newest
  /// progress — keep the story going (next line / write the missing beat).
  void _forward() {
    _stopFastForward();
    if (_history.canForward) {
      _goForward();
      return;
    }
    if (_runtime.canAdvance) {
      _advance();
      return;
    }
    if (_runtime.needsBridge) _ensureBridge();
  }

  /// Replays recorded lines until the newest progress; stops there.
  void _startFastForward() {
    if (_fastForwardTimer != null || !_history.canForward) return;
    AppLog.instance.info(
      '视觉小说快进：剩余 ${_history.entries.length - 1 - _history.cursor} 步',
      tag: 'play.vn',
    );
    _fastForwardTimer = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) {
        final target = _history.stepForward();
        if (target == null) {
          _stopFastForward();
          return;
        }
        _restorePosition(target, persist: false);
        if (!_history.canForward) _stopFastForward();
      },
    );
    setState(() {});
  }

  void _stopFastForward() {
    final timer = _fastForwardTimer;
    if (timer == null) return;
    timer.cancel();
    _fastForwardTimer = null;
    if (mounted) setState(() {});
    _persist();
  }

  void _restorePosition(MainSavePointer target, {bool persist = true}) {
    setState(() {
      _runtime.restore(target);
      _syncBridgeNode();
      _status = null;
    });
    if (persist) _persist();
  }

  /// Tap on the stage: replay forward when scrubbed back, otherwise next line
  /// (or take a prefetched / freshly generated beat).
  void _onStageTap() {
    _stopFastForward();
    if (_history.canForward) {
      _goForward();
      return;
    }
    if (_runtime.canAdvance) {
      _advance();
      return;
    }
    if (!_runtime.needsBridge) return;
    // Empty buffer still generating: keep current dialogue, wait.
    if (_prefetchQueue.isEmpty && _generating) return;
    _ensureBridge();
  }

  Future<void> _onChatSend(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _chatLocked) return;
    await _appendUserAndGenerate(text);
  }

  Future<void> _onPickReply(String choice) async {
    final text = choice.trim();
    if (text.isEmpty || _chatLocked) return;
    await _appendUserAndGenerate(text);
  }

  Future<void> _appendUserAndGenerate(String text) async {
    setState(() {
      _chat.add(
        TavernChatMessage(
          id: _newChatId('user'),
          role: TavernChatRole.user,
          content: text,
        ),
      );
      _replyChoices = const [];
      _status = null;
    });
    await _persist();
    await _generateAssistantTurn(refreshChoices: true);
  }

  Future<void> _ensureChatOpening() async {
    if (!_isChat || !mounted || _chatLocked) return;
    if (_chat.isNotEmpty) {
      // Exact restore: do not regenerate choices when already saved.
      await _persist();
      return;
    }
    // First open: create a slot immediately, then write opening.
    await _persist();
    await _generateAssistantTurn(refreshChoices: true);
  }

  Future<void> _generateAssistantTurn({required bool refreshChoices}) async {
    if (!mounted || _chatLocked) return;
    setState(() {
      _assistantBusy = true;
      _status = context.strings.statusWriting;
    });

    final settings = AppScope.settingsOf(context);
    final ctx = settings.textPromptContext();
    try {
      final action = TavernChatGenerateAction(
        textClient: AppScope.textClientOf(context),
      );
      final result = await action.generate(
        ctx: ctx,
        project: _project,
        history: List<TavernChatMessage>.unmodifiable(_chat),
      );
      if (!mounted) return;
      setState(() {
        _chat.add(
          TavernChatMessage(
            id: _newChatId('assistant'),
            role: TavernChatRole.assistant,
            content: result.content,
            reasoning: result.reasoning,
          ),
        );
        _assistantBusy = false;
        _status = null;
      });
      await _persist();
      if (refreshChoices) {
        await _refreshReplyChoices();
      }
    } on AiTextException catch (error) {
      if (!mounted) return;
      setState(() {
        _assistantBusy = false;
        _status = error.message;
      });
      await _persist();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assistantBusy = false;
        _status = context.strings.statusTurnFailed;
      });
      await _persist();
    }
  }

  bool get _canRegenerateChat {
    if (!_isChat || _chatLocked || _chat.isEmpty) return false;
    return _chat.last.role == TavernChatRole.assistant;
  }

  /// VN: redo the upcoming beat, or drop the current AI beat (and everything
  /// after it) then write a replacement from that cut point.
  bool get _canRegenerateVn {
    if (_isChat || _runtime.pointer.isEnded) return false;
    if (_runtime.needsBridge) return true;
    final beatId = _runtime.pointer.beatId;
    if (beatId.isEmpty) return false;
    final bridge = _bridge;
    if (bridge == null) return false;
    return bridge.generatedBeats.any((b) => b.id == beatId);
  }

  Future<void> _regenerateLastAssistant() async {
    if (!_canRegenerateChat) return;
    setState(() {
      _chat.removeLast();
      _replyChoices = const [];
      _status = null;
    });
    await _persist();
    await _generateAssistantTurn(refreshChoices: true);
  }

  Future<void> _regenerateVnSegment() async {
    if (!_canRegenerateVn) return;
    _stopFastForward();
    // Cancel in-flight adopt / prefetch so a stale reply cannot land.
    _invalidatePrefetch();

    final nodeId = _runtime.pointer.nodeId;
    final beatId = _runtime.pointer.beatId;

    if (_runtime.needsBridge) {
      AppLog.instance.info('重新生成：重写下一段', tag: 'play.vn');
      setState(() => _status = null);
      await _persist();
      await _ensureBridge();
      return;
    }

    final bridge = _bridge;
    if (bridge == null || beatId.isEmpty) return;
    final dropFrom = bridge.generatedBeats.indexWhere((b) => b.id == beatId);
    if (dropFrom < 0) return;

    final kept = bridge.generatedBeats.sublist(0, dropFrom);
    _history.truncateFromBeat(beatId);

    final main = _mergeBeats(_baseMain, kept);
    final resume = _history.current;
    final runtime = resume == null
        ? MainRuntime(main, save: MainSavePointer(nodeId: nodeId, beatId: ''))
        : MainRuntime(main, save: resume);
    // Always reopen the interval so the next generate replaces the cut beat.
    if (!runtime.needsBridge) {
      runtime.requestBridge();
    }

    final nextBridge = BridgeSession(
      nodeId: nodeId,
      generatedBeats: kept,
      turnCount: kept.where((b) => b.nodeId == nodeId).length,
      summary: kept
          .where((b) => b.nodeId == nodeId)
          .map((b) => b.lines.map((l) => l.text).join(' '))
          .join(' ')
          .trim(),
    );

    AppLog.instance.info(
      '重新生成：截断拍 $beatId（保留 ${kept.length} 拍）',
      tag: 'play.vn',
    );

    setState(() {
      _runtime = runtime;
      _bridge = nextBridge;
      _status = null;
    });
    await _persist();
    await _ensureBridge();
  }

  void _openChatSettings() {
    pushAppSlide(context, const ChatSettingsPage());
  }

  Future<void> _refreshReplyChoices() async {
    if (!mounted || _assistantBusy || _choicesBusy) return;
    if (_chat.isEmpty || _chat.last.role != TavernChatRole.assistant) {
      return;
    }
    setState(() => _choicesBusy = true);
    try {
      final action = TavernReplyChoiceAction(
        textClient: AppScope.textClientOf(context),
      );
      final choices = await action.generate(
        ctx: AppScope.settingsOf(context).textPromptContext(),
        project: _project,
        history: List<TavernChatMessage>.unmodifiable(_chat),
      );
      if (!mounted) return;
      setState(() {
        _replyChoices = choices;
        _choicesBusy = false;
      });
      await _persist();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _replyChoices = const [];
        _choicesBusy = false;
      });
      await _persist();
    }
  }

  void _syncBridgeNode() {
    final nodeId = _runtime.pointer.nodeId;
    final current = _bridge;
    if (current == null) {
      _bridge = BridgeSession(nodeId: nodeId);
      return;
    }
    if (current.nodeId == nodeId) return;
    // Station change invalidates stay-path prefetch.
    _invalidatePrefetch();
    // Keep every generated beat for rollback; reset interval counters only.
    _bridge = current.copyWith(
      nodeId: nodeId,
      turnCount: current.turnsForNode(nodeId),
      summary: '',
    );
  }

  void _invalidatePrefetch() {
    _prefetchQueue.clear();
    _generateEpoch++;
    _generating = false;
    _prefetchPaused = false;
  }

  void _restart() {
    _stopFastForward();
    setState(() {
      _invalidatePrefetch();
      _runtime = MainRuntime(_baseMain);
      _bridge = null;
      _chat.clear();
      _replyChoices = const [];
      _status = context.strings.statusRestarted;
      _history.clear();
      _recordPosition();
    });
    if (_isChat) {
      _persist().then((_) {
        if (mounted) _ensureChatOpening();
      });
    } else {
      _persist();
      _ensureBridge();
    }
  }

  /// Session view used for the next generate call (includes queued prefetch).
  BridgeSession _sessionForNextGenerate(String nodeId) {
    final base = _bridge ?? BridgeSession(nodeId: nodeId);
    if (_prefetchQueue.isEmpty) return base;
    final queuedText = _prefetchQueue
        .map((b) => b.lines.map((l) => l.text).join(' '))
        .join(' ');
    return base.copyWith(
      turnCount: base.turnCount + _prefetchQueue.length,
      summary: '${base.summary} $queuedText'.trim(),
    );
  }

  bool _canPrefetchMore(String nodeId) {
    if (_runtime.pointer.isEnded) return false;
    final node = _runtime.main.nodeById(nodeId);
    if (node == null || node.tags.contains('ending')) return false;
    final hasOutbound =
        _runtime.main.edges.any((e) => e.from == nodeId);
    if (!hasOutbound) return true;
    final base = _bridge ?? BridgeSession(nodeId: nodeId);
    final planned = base.turnCount + _prefetchQueue.length;
    return planned < BridgeSession.defaultMaxBeats;
  }

  Future<void> _ensureBridge() async {
    if (_isChat || !mounted) return;

    final node = _runtime.currentNode;
    if (node == null) return;

    if (_runtime.needsBridge && node.tags.contains('ending')) {
      setState(() {
        _runtime.endStory();
        _recordPosition();
      });
      await _persist();
      return;
    }

    if (_runtime.needsBridge) {
      _syncBridgeNode();
      if (_prefetchQueue.isNotEmpty) {
        _consumePrefetch();
        // Refill as soon as the buffer drops below 2 — don't wait on disk.
        _maintainPrefetchBuffer();
        _persist();
        return;
      }
      // A background write may be about to land in the queue; wait for it.
      if (_generating) return;
      await _generateOne(adopt: true);
      _maintainPrefetchBuffer();
      return;
    }

    // While reading AI content, keep the background buffer at 2.
    if (_shouldMaintainPrefetch) {
      _maintainPrefetchBuffer();
    }
  }

  /// Once the AI interval has started, always aim for [_prefetchTarget] ahead.
  bool get _shouldMaintainPrefetch {
    if (_runtime.pointer.isEnded) return false;
    if (_runtime.needsBridge) return true;
    final bridge = _bridge;
    if (bridge == null) return false;
    if (bridge.generatedBeats.isNotEmpty) return true;
    return _prefetchQueue.isNotEmpty;
  }

  /// Start a background write whenever reserved beats are below target.
  Future<void> _maintainPrefetchBuffer() async {
    if (_isChat || !mounted || _generating) return;
    if (!_shouldMaintainPrefetch && !_runtime.needsBridge) return;
    final node = _runtime.currentNode;
    if (node == null) return;
    if (_prefetchQueue.length >= _prefetchTarget) return;
    if (!_canPrefetchMore(node.id)) return;
    // Hard need (empty + waiting): clear a prior soft pause so play can resume.
    if (_prefetchPaused) {
      if (_prefetchQueue.isNotEmpty || !_runtime.needsBridge) return;
      _prefetchPaused = false;
    }

    AppLog.instance.info(
      '后台预写第 ${_prefetchQueue.length + 1}/$_prefetchTarget 拍',
      tag: 'play.vn',
    );
    await _generateOne(adopt: false);
    if (!mounted) return;
    // Keep going until the buffer holds two reserved beats.
    _maintainPrefetchBuffer();
  }

  void _consumePrefetch() {
    if (_prefetchQueue.isEmpty) return;
    final beat = _prefetchQueue.removeAt(0);
    final session = _bridge ?? BridgeSession(nodeId: beat.nodeId);
    AppLog.instance.info(
      '采用预写拍 ${beat.id}，缓冲剩余 ${_prefetchQueue.length}',
      tag: 'play.vn',
    );
    _adoptBeat(beat, session);
  }

  void _adoptBeat(Beat beat, BridgeSession session) {
    setState(() {
      _runtime.adoptBridgeBeat(beat);
      _recordPosition();
      _bridge = session.copyWith(
        generatedBeats: [...session.generatedBeats, beat],
        turnCount: session.turnCount + 1,
        summary:
            '${session.summary} ${beat.lines.map((l) => l.text).join(' ')}'
                .trim(),
      );
      _generating = false;
      _prefetchPaused = false;
      _status = null;
    });
  }

  /// After a reserved beat lands: feed the player if they are waiting, then refill.
  Future<void> _onPrefetchArrived() async {
    if (!mounted) return;
    if (_runtime.needsBridge && _prefetchQueue.isNotEmpty) {
      _consumePrefetch();
      await _persist();
    }
    _maintainPrefetchBuffer();
  }

  Future<void> _generateOne({required bool adopt}) async {
    final node = _runtime.currentNode;
    if (node == null || _generating) return;

    final epoch = _generateEpoch;
    final session = _sessionForNextGenerate(node.id);

    setState(() {
      _generating = true;
      // Keep the last on-screen line; never flash "正在写这一段".
      if (adopt) _status = null;
    });

    final settings = AppScope.settingsOf(context);
    try {
      final action = BridgeGenerateAction(
        textClient: AppScope.textClientOf(context),
      );
      final beat = await action.generate(
        ctx: settings.textPromptContext(),
        project: _project.copyWith(main: _runtime.main),
        nodeId: node.id,
        session: session,
        plotCatalog: settings.plotElements,
        userAliases: _userAliases(),
        minLines: settings.ai.minBridgeLines,
      );
      if (!mounted || epoch != _generateEpoch) return;
      if (adopt) {
        _adoptBeat(beat, _bridge ?? BridgeSession(nodeId: node.id));
        await _persist();
      } else {
        setState(() {
          _prefetchQueue.add(beat);
          _generating = false;
        });
        AppLog.instance.info(
          '预写完成 ${beat.id}（缓冲 ${_prefetchQueue.length}/$_prefetchTarget）',
          tag: 'play.vn',
        );
        await _onPrefetchArrived();
      }
    } on AiTextException catch (error) {
      if (!mounted || epoch != _generateEpoch) return;
      final fallback = _fallbackBeat(
        nodeId: node.id,
        turn: session.turnCount + 1,
        text: error.message,
      );
      if (adopt) {
        _adoptBeat(fallback, _bridge ?? BridgeSession(nodeId: node.id));
        setState(() => _status = context.strings.statusSafeExit);
        await _persist();
      } else {
        // Prefetch failure: pause until the next adopt; player can still play.
        setState(() {
          _generating = false;
          _prefetchPaused = true;
        });
        AppLog.instance.warning(
          '后台预写失败：${error.message}',
          tag: 'play.vn',
        );
        // If the player is already waiting, fall through to a blocking adopt.
        if (_runtime.needsBridge && _prefetchQueue.isEmpty) {
          _prefetchPaused = false;
          await _generateOne(adopt: true);
          _maintainPrefetchBuffer();
        }
      }
    } catch (error, stack) {
      if (!mounted || epoch != _generateEpoch) return;
      AppLog.instance.error(
        '区间生成异常',
        tag: 'play.vn',
        error: error,
        stackTrace: stack,
      );
      final fallback = _fallbackBeat(
        nodeId: node.id,
        turn: session.turnCount + 1,
        text: context.strings.fallbackBeatText,
      );
      if (adopt) {
        _adoptBeat(fallback, _bridge ?? BridgeSession(nodeId: node.id));
        setState(() => _status = context.strings.statusSafeExit);
        await _persist();
      } else {
        setState(() {
          _generating = false;
          _prefetchPaused = true;
        });
        if (_runtime.needsBridge && _prefetchQueue.isEmpty) {
          _prefetchPaused = false;
          await _generateOne(adopt: true);
          _maintainPrefetchBuffer();
        }
      }
    }
  }

  Beat _fallbackBeat({
    required String nodeId,
    required int turn,
    required String text,
  }) {
    return Beat(
      id: 'bridge_fallback_$turn',
      nodeId: nodeId,
      scene: const Scene(),
      appearances: const [],
      lines: [
        DialogueLine(
          id: 'bridge_fallback_l0',
          text: text,
          kind: DialogueKind.narration,
        ),
      ],
      choices: BridgeGenerateAction.fallbackChoices(_runtime.main, nodeId),
    );
  }

  List<_VnCenterAction> _centerActions() {
    // Hide choices only while the player is blocked waiting for the next beat.
    if (_waitingForBeat) return const [];
    if (_runtime.pointer.isEnded) {
      return [
        _VnCenterAction(
          label: context.strings.restart,
          onPressed: _restart,
          variant: AppButtonVariant.primary,
        ),
      ];
    }
    if (_runtime.pointer.phase == PlayPhase.choices) {
      final actions = <_VnCenterAction>[
        for (final choice in _runtime.visibleChoices)
          _VnCenterAction(
            label: choice.text,
            onPressed: () => _choose(choice),
            variant: AppButtonVariant.secondary,
          ),
      ];
      if (actions.isEmpty) {
        actions.addAll(_fallbackExitActions());
      }
      return actions;
    }
    if (_runtime.needsBridge) {
      return _fallbackExitActions();
    }
    return const [];
  }

  List<_VnCenterAction> _fallbackExitActions() {
    final outs = _runtime.outboundFromCurrent();
    if (outs.isEmpty) return const [];
    return [
      for (final edge in outs)
        _VnCenterAction(
          label: context.strings.gotoNode(
            _runtime.main.nodeById(edge.to)?.title ?? edge.to,
          ),
          onPressed: () {
            _stopFastForward();
            setState(() {
              _runtime.jumpToNode(edge.to);
              _syncBridgeNode();
              _recordPosition();
            });
            _persist();
            _ensureBridge();
          },
          variant: AppButtonVariant.secondary,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final chatMode = _isChat;
    final title = widget.project.meta.title;
    return AppPage(
      title: title,
      // Chat keeps a quieter header than other large page titles.
      titleWidget: chatMode
          ? AppText(
              title,
              role: AppTextRole.subtitle,
              maxLines: 1,
            )
          : null,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        if (!chatMode && _canRegenerateVn)
          AppCircleButton(
            icon: Icons.refresh_rounded,
            tooltip: context.strings.regenerateSegment,
            onPressed: _regenerateVnSegment,
          ),
        if (!chatMode && _generating)
          AppBusyIndicator(
            semanticLabel: context.strings.generatingSegment,
          ),
        if (chatMode && _canRegenerateChat)
          AppCircleButton(
            icon: Icons.refresh_rounded,
            tooltip: context.strings.regenerateReply,
            onPressed: _regenerateLastAssistant,
          ),
      ],
      body: chatMode
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      AppTheme.spaceSm,
                      AppTheme.pagePadding,
                      0,
                    ),
                    child: AppText(_status!, role: AppTextRole.caption),
                  ),
                Expanded(
                  child: PlayChatView(
                    messages: _chatUiMessages,
                    replyChoices: _replyChoices,
                    isGenerating: _assistantBusy,
                    inputLocked: _choicesBusy,
                    title: widget.project.meta.title,
                    onSend: _onChatSend,
                    onPickReply: _onPickReply,
                    onPickModel: () => pickAndApplyTextModel(context),
                    onOpenSettings: _openChatSettings,
                    onRefreshChoices: _refreshReplyChoices,
                  ),
                ),
              ],
            )
          : _VnStage(
              runtime: _runtime,
              speakerLabel: _speakerLabel,
              isNarration: _isNarration,
              // Errors / soft notices only — never the writing placeholder.
              status: _status,
              centerActions: _centerActions(),
              canBack: _history.canBack,
              canForward: _history.canForward || _canContinueStory,
              canFastForward: _history.canForward,
              fastForwarding: _fastForwardTimer != null,
              onStageTap: _onStageTap,
              onBack: _goBack,
              onForward: _forward,
              onFastForward:
                  _fastForwardTimer != null ? _stopFastForward : _startFastForward,
            ),
    );
  }
}

class _VnCenterAction {
  const _VnCenterAction({
    required this.label,
    required this.onPressed,
    required this.variant,
  });

  final String label;
  final VoidCallback onPressed;
  final AppButtonVariant variant;
}

class _VnStage extends StatelessWidget {
  const _VnStage({
    required this.runtime,
    required this.speakerLabel,
    required this.isNarration,
    required this.status,
    required this.centerActions,
    required this.canBack,
    required this.canForward,
    required this.canFastForward,
    required this.fastForwarding,
    required this.onStageTap,
    required this.onBack,
    required this.onForward,
    required this.onFastForward,
  });

  final MainRuntime runtime;
  final String? Function(DialogueLine) speakerLabel;
  final bool Function(DialogueLine) isNarration;
  final String? status;
  final List<_VnCenterAction> centerActions;
  final bool canBack;
  final bool canForward;
  final bool canFastForward;
  final bool fastForwarding;
  final VoidCallback onStageTap;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onFastForward;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final line = runtime.currentLine;
    final showChoices = centerActions.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Very short viewports: keep the dialogue readable, drop the history bar.
        final showHistory = constraints.maxHeight >= 260;
        final maxDialogueHeight =
            (constraints.maxHeight * 0.55).clamp(96.0, 360.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onStageTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _VnBackground(),
              Column(
                children: [
                  Expanded(
                    child: showChoices
                        ? _VnChoiceOverlay(actions: centerActions)
                        : const SizedBox.expand(),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      0,
                      AppTheme.pagePadding,
                      AppTheme.pagePadding + bottomInset,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxHeight: maxDialogueHeight),
                          child: _VnDialogueBox(
                            line: runtime.pointer.isEnded ? null : line,
                            speaker: runtime.pointer.isEnded || line == null
                                ? null
                                : speakerLabel(line),
                            narration: !runtime.pointer.isEnded &&
                                line != null &&
                                isNarration(line),
                            accent: scheme.primary,
                            placeholder: () {
                              if (runtime.pointer.isEnded) {
                                return strings.segmentEnded;
                              }
                              if (line != null) return null;
                              if (runtime.pointer.phase == PlayPhase.choices) {
                                return strings.choosePlease;
                              }
                              // Waiting for the next beat: keep the box quiet;
                              // title-bar spinner is the only busy signal.
                              if (runtime.needsBridge) return '…';
                              return '…';
                            }(),
                            status: status,
                          ),
                        ),
                        if (showHistory) ...[
                          const SizedBox(height: AppTheme.spaceSm),
                          _VnHistoryBar(
                            enabled: true,
                            canBack: canBack,
                            canForward: canForward,
                            canFastForward: canFastForward,
                            fastForwarding: fastForwarding,
                            onBack: onBack,
                            onForward: onForward,
                            onFastForward: onFastForward,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Back / forward / fast-forward row under the dialogue box.
class _VnHistoryBar extends StatelessWidget {
  const _VnHistoryBar({
    required this.enabled,
    required this.canBack,
    required this.canForward,
    required this.canFastForward,
    required this.fastForwarding,
    required this.onBack,
    required this.onForward,
    required this.onFastForward,
  });

  /// Generation in flight: rewinding would be overridden when the beat lands.
  final bool enabled;
  final bool canBack;

  /// Forward can also keep the story going at the newest progress.
  final bool canForward;

  /// Fast-forward only replays recorded lines, so it needs history ahead.
  final bool canFastForward;
  final bool fastForwarding;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onFastForward;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIconButton(
          icon: Icons.skip_previous_rounded,
          tooltip: strings.historyBack,
          onPressed: enabled && canBack ? onBack : null,
        ),
        const SizedBox(width: AppTheme.spaceMd),
        AppIconButton(
          icon: Icons.skip_next_rounded,
          tooltip: strings.historyForward,
          onPressed: enabled && canForward ? onForward : null,
        ),
        const SizedBox(width: AppTheme.spaceMd),
        AppIconButton(
          icon: fastForwarding
              ? Icons.pause_rounded
              : Icons.fast_forward_rounded,
          tooltip: strings.historyFastForward,
          onPressed: enabled && (canFastForward || fastForwarding)
              ? onFastForward
              : null,
        ),
      ],
    );
  }
}

/// Full-bleed stage backdrop. Asset wiring comes later; empty = plain canvas.
class _VnBackground extends StatelessWidget {
  const _VnBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).colorScheme.surface);
  }
}

class _VnChoiceOverlay extends StatelessWidget {
  const _VnChoiceOverlay({required this.actions});

  final List<_VnCenterAction> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.pagePadding,
          horizontal: AppTheme.pagePadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppTheme.spaceSm),
                AppButton(
                  label: actions[i].label,
                  onPressed: actions[i].onPressed,
                  variant: actions[i].variant,
                  expanded: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VnDialogueBox extends StatelessWidget {
  const _VnDialogueBox({
    required this.line,
    required this.speaker,
    required this.narration,
    required this.accent,
    required this.placeholder,
    required this.status,
  });

  final DialogueLine? line;
  final String? speaker;
  final bool narration;
  final Color accent;
  final String? placeholder;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final body = line == null
        ? null
        : stripDialogueSpeakerLabel(line!.text);

    return AppSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status != null) ...[
              AppText(status!, role: AppTextRole.caption),
              const SizedBox(height: AppTheme.spaceSm),
            ],
            if (speaker != null) ...[
              AppText(
                speaker!,
                role: AppTextRole.label,
                color: accent,
                fontWeight: FontWeight.w700,
                maxLines: 1,
              ),
              const SizedBox(height: AppTheme.spaceSm),
            ],
            if (body != null)
              AppText(
                body,
                role: AppTextRole.body,
                fontStyle: narration ? FontStyle.italic : null,
              )
            else if (placeholder != null)
              AppText(
                placeholder!,
                role: AppTextRole.body,
                fontStyle: FontStyle.italic,
              ),
          ],
        ),
      ),
    );
  }
}
