import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_branch_prefetch_action.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/chat/tavern_chat_generate_action.dart';
import 'package:anoworld/domain/chat/tavern_reply_choice_action.dart';
import 'package:anoworld/domain/main/merge_generated_beats.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/main_runtime.dart';
import 'package:anoworld/domain/runtime/play_history.dart';
import 'package:anoworld/domain/runtime/play_pointer.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:anoworld/domain/settings/vn_ui_settings.dart';
import 'package:anoworld/foundation/l10n/app_localizations.dart';
import 'package:anoworld/foundation/text/text_paginator.dart';
import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';
import 'package:anoworld/foundation/theme/app_hex_color.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_dialogue_panel.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/foundation/widgets/app_typewriter_text.dart';
import 'package:anoworld/play/play_chat_message.dart';
import 'package:anoworld/play/play_chat_view.dart';
import 'package:anoworld/play/chat_settings_page.dart';
import 'package:anoworld/play/vn_settings_page.dart';
import 'package:anoworld/settings/ai_model_picker.dart';
import 'package:flutter/material.dart';

export 'package:anoworld/domain/runtime/play_view_mode.dart' show PlayViewMode;

/// Full-page VN stage art (also painted behind the window / status chrome).
const Key vnBackdropKey = ValueKey('vn.stage.backdrop');

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
    this.playerCastId,
  });

  final Project project;
  final PlayViewMode mode;

  /// Existing save slot to resume; null means allocate a new id.
  final String? slotId;
  final bool resumeSave;
  final MainSavePointer? initialSave;

  /// Cast member the player role-plays; locked for the slot. Null falls back to
  /// the protagonist (legacy slots / stories without a chosen role).
  final String? playerCastId;

  @override
  State<PlaySessionPage> createState() => _PlaySessionPageState();
}

class _PlaySessionPageState extends State<PlaySessionPage> {
  late MainRuntime _runtime;
  late String _slotId;
  BridgeSession? _bridge;
  String? _status;
  bool _bootstrapped = false;

  /// Cast member the player role-plays; locked for this session.
  String? _playerCastId;

  /// VN AI call in flight (immediate adopt or background prefetch).
  bool _generating = false;

  /// Beat id currently arriving line by line (VN streaming).
  String? _streamBeatId;

  bool _assistantBusy = false;
  bool _choicesBusy = false;

  /// Chat: the player asked to stop the streaming reply.
  bool _chatStopRequested = false;

  /// Live subscription + completion for the chat stream, so stop can cut it.
  StreamSubscription<TavernChatChunk>? _chatSub;
  Completer<void>? _chatDone;

  /// Linear stay-path beats ahead of the player (not yet adopted).
  /// Target depth: [_prefetchTarget] while the newest beat has no choices.
  final List<Beat> _prefetchQueue = <Beat>[];
  static const int _prefetchTarget = 2;

  /// Beat id for which branch batch prefetch was armed / completed.
  String? _branchSourceBeatId;

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

  /// Absolute project folder (for resolving `assets/` images).
  String? _projectDir;

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

  /// Default role when the caller did not pick one: the flagged protagonist,
  /// else the first member.
  String? get _defaultPlayerCastId {
    final protagonist = _project.protagonist;
    if (protagonist != null) return protagonist.id;
    return _project.cast.isEmpty ? null : _project.cast.first.id;
  }

  List<String> _playerAliases() {
    final persona = AppScope.settingsOf(context).activePersona;
    return <String>[
      if (persona != null && persona.name.trim().isNotEmpty) persona.name.trim(),
      '我',
      '玩家',
      '用户',
      'User',
      '{{user}}',
    ];
  }

  PlayRole get _playRole =>
      PlayRole(playerCastId: _playerCastId, aliases: _playerAliases());

  String get _assistantLabel {
    // Chat keeps the card's protagonist; only a VN session shifts focus to the
    // character that is not the player.
    if (_isChat) {
      final lead = _project.protagonist;
      if (lead != null) return lead.name;
      if (_project.cast.isNotEmpty) return _project.cast.first.name;
      return context.strings.castLabelFallback;
    }
    final focus = _playRole.focusIn(_project);
    if (focus != null) return focus.name;
    final lead = _project.protagonist;
    if (lead != null) return lead.name;
    if (_project.cast.isNotEmpty) return _project.cast.first.name;
    return context.strings.castLabelFallback;
  }

  List<PlayChatMessage> get _chatUiMessages {
    final user = _userLabel;
    final assistant = _assistantLabel;
    final streamingIndex = _assistantBusy &&
            _chat.isNotEmpty &&
            _chat.last.role == TavernChatRole.assistant
        ? _chat.length - 1
        : -1;
    return [
      for (var i = 0; i < _chat.length; i++)
        PlayChatMessage.fromTavern(
          _chat[i],
          userLabel: user,
          assistantLabel: assistant,
          streaming: i == streamingIndex,
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
    _playerCastId = widget.playerCastId ?? _defaultPlayerCastId;
    _runtime = MainRuntime(_baseMain, save: widget.initialSave);
    unawaited(_resolveProjectDir());
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

  Future<void> _resolveProjectDir() async {
    try {
      final dir =
          await AppScope.projectsOf(context).directoryFor(_project.meta.id);
      if (!mounted) return;
      setState(() => _projectDir = dir);
    } catch (_) {
      // Background stays empty if the folder cannot be resolved.
    }
  }

  @override
  void dispose() {
    _fastForwardTimer?.cancel();
    unawaited(_chatSub?.cancel());
    _chatSub = null;
    final done = _chatDone;
    _chatDone = null;
    if (done != null && !done.isCompleted) done.complete();
    _generateEpoch++;
    super.dispose();
  }

  Future<void> _loadSlot(String slotId) async {
    final slot = await AppScope.savesOf(context).load(slotId);
    if (!mounted) return;
    if (slot != null) {
      // Reopening a slot keeps the character chosen when it was created.
      final locked = slot.playerCastId;
      if (locked != null && locked.isNotEmpty) _playerCastId = locked;
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
          final beats = [
            for (final beat in bridge.generatedBeats)
              _normalizeBeatSpeakers(beat),
          ];
          main = _mergeBeats(main, beats);
          _bridge = bridge.copyWith(
            generatedBeats: List<Beat>.unmodifiable(beats),
          );
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
        setState(() => _status = null);
        // Resume notice is a passing toast, not a line above the story.
        final message = context.strings.progressLoaded;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showAppToast(context, message);
        });
      }
    }
    if (_isChat) {
      await _ensureChatOpening();
    } else {
      await _ensureBridge();
    }
  }

  MainStory _mergeBeats(MainStory main, List<Beat> beats) =>
      mergeGeneratedBeats(main, beats);

  bool _isNarration(DialogueLine line) {
    if (line.kind == DialogueKind.narration) return true;
    final speakerId = line.speakerId;
    if (speakerId == null || speakerId.isEmpty) return true;
    // A speaker that is not a defined cast member is narration, never a label.
    return _project.castById(speakerId) == null;
  }

  String? _speakerLabel(DialogueLine line) {
    if (_isNarration(line)) return null;
    // Only a defined cast member may be labelled; unknown ids stay narration.
    return _project.castById(line.speakerId!)?.name;
  }

  /// Re-resolves legacy string speakers (old saves stored model names raw).
  ///
  /// Beats written before the strict protocol may carry e.g. `speakerId:
  /// "梦涵"`. Map them through the same resolver so the stage agrees with new
  /// beats; unknown names become narration.
  Beat _normalizeBeatSpeakers(Beat beat) {
    var changed = false;
    final lines = <DialogueLine>[];
    for (final line in beat.lines) {
      final speakerId = line.speakerId;
      final needsResolve = line.kind == DialogueKind.speech &&
          speakerId != null &&
          _project.castById(speakerId) == null;
      if (!needsResolve) {
        lines.add(line);
        continue;
      }
      final resolved = resolveDialogueSpeaker(
        speaker: speakerId,
        project: _project,
        role: _playRole,
      );
      lines.add(
        DialogueLine(
          id: line.id,
          text: line.text,
          speakerId: resolved.castId,
          kind:
              resolved.recognized ? DialogueKind.speech : DialogueKind.narration,
        ),
      );
      changed = true;
    }
    return changed ? beat.copyWith(lines: List<DialogueLine>.unmodifiable(lines)) : beat;
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
      playerCastId: _isChat ? null : _playerCastId,
    );
  }

  void _advance() {
    if (!_runtime.canAdvance) return;
    final beat = _runtime.currentBeat;
    // Streaming beat: the last arrived line is the edge — wait for more.
    if (beat != null &&
        beat.id == _streamBeatId &&
        _runtime.pointer.lineIndex >= beat.lines.length - 1) {
      return;
    }
    setState(() {
      _runtime.advance();
      _recordPosition();
    });
    _persist();
    _ensureBridge();
  }

  Future<void> _choose(Choice choice) async {
    _stopFastForward();
    final fromBeatId = _runtime.pointer.beatId;
    final linkedId = _bridge?.toBeatId(fromBeatId, choice.id);
    final linked =
        linkedId == null ? null : _bridge?.beatById(linkedId);

    setState(() {
      _runtime.choose(choice.id);
      _syncBridgeNode();
      _recordPosition();
      _branchSourceBeatId = null;
    });

    // Reuse a beat already grown on the story tree for this choice.
    if (linked != null && _runtime.needsBridge) {
      AppLog.instance.info('采用分支预写', tag: 'play.vn');
      _adoptBeat(
        linked,
        _bridge ?? BridgeSession(nodeId: linked.nodeId),
        fromBeatId: fromBeatId,
        choiceId: choice.id,
      );
      await _persist();
      _maintainPrefetchBuffer();
      return;
    }

    await _persist();
    await _ensureBridge(
      linkFromBeatId: fromBeatId.isEmpty ? null : fromBeatId,
      linkChoiceId: fromBeatId.isEmpty ? null : choice.id,
    );
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
    _chatStopRequested = false;
    setState(() {
      _assistantBusy = true;
      _status = context.strings.statusWriting;
    });

    final settings = AppScope.settingsOf(context);
    final strings = context.strings;
    final ctx = settings.textPromptContext();
    final action = TavernChatGenerateAction(
      textClient: AppScope.textClientOf(context),
    );
    final messageId = _newChatId('assistant');
    final content = StringBuffer();
    final reasoning = StringBuffer();
    final clock = Stopwatch()..start();
    var added = false;
    var lastPaint = 0;

    /// Applies the streamed text to the bubble; throttled to keep rebuilds cheap.
    void paint({bool force = false}) {
      if (!mounted) return;
      final now = clock.elapsedMilliseconds;
      if (!force && now - lastPaint < 50) return;
      lastPaint = now;
      setState(() {
        final text = content.toString();
        if (!added) {
          added = true;
          _chat.add(
            TavernChatMessage(
              id: messageId,
              role: TavernChatRole.assistant,
              content: text,
              reasoning: _reasoningOrNull(reasoning),
            ),
          );
          _status = null;
          return;
        }
        _replaceChatMessage(
          messageId,
          content: text,
          reasoning: _reasoningOrNull(reasoning),
        );
      });
    }

    void dropPartialIfEmpty() {
      if (added && content.toString().trim().isEmpty) {
        _chat.removeWhere((m) => m.id == messageId);
      }
    }

    try {
      final done = Completer<void>();
      final sub = action
          .streamGenerate(
            ctx: ctx,
            project: _project,
            history: List<TavernChatMessage>.unmodifiable(_chat),
            plotCatalog: settings.plotElements,
          )
          .listen(
            (chunk) {
              if (_chatStopRequested) return;
              content.write(chunk.content);
              reasoning.write(chunk.reasoning);
              paint();
            },
            onError: (Object error, StackTrace stack) {
              if (!done.isCompleted) done.completeError(error, stack);
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      _chatSub = sub;
      _chatDone = done;
      try {
        await done.future;
      } finally {
        if (identical(_chatSub, sub)) _chatSub = null;
        if (identical(_chatDone, done)) _chatDone = null;
        await sub.cancel();
      }
      if (!mounted) return;
      final stopped = _chatStopRequested;
      final text = content.toString().trim();
      final reasoningText = _reasoningOrNull(reasoning);
      setState(() {
        dropPartialIfEmpty();
        if (added && text.isNotEmpty) {
          _replaceChatMessage(
            messageId,
            content: text,
            reasoning: reasoningText,
          );
        }
        _assistantBusy = false;
        _status = stopped
            ? strings.statusStopped
            : (text.isEmpty ? strings.statusTurnFailed : null);
      });
      await _persist();
      if (refreshChoices && !stopped && text.isNotEmpty) {
        await _refreshReplyChoices();
      }
    } on AiTextException catch (error) {
      if (!mounted) return;
      setState(() {
        dropPartialIfEmpty();
        _assistantBusy = false;
        _status = error.message;
      });
      await _persist();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        dropPartialIfEmpty();
        _assistantBusy = false;
        _status = strings.statusTurnFailed;
      });
      await _persist();
    }
  }

  static String? _reasoningOrNull(StringBuffer buffer) {
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Replaces one chat bubble in place (streaming reply growth).
  void _replaceChatMessage(
    String id, {
    required String content,
    String? reasoning,
  }) {
    final index = _chat.lastIndexWhere((m) => m.id == id);
    if (index < 0) return;
    _chat[index] = TavernChatMessage(
      id: id,
      role: TavernChatRole.assistant,
      content: content,
      reasoning: reasoning,
    );
  }

  /// Stops the streaming reply; whatever was already written stays.
  void _stopChatStream() {
    if (!_assistantBusy) return;
    _chatStopRequested = true;
    unawaited(_chatSub?.cancel());
    _chatSub = null;
    final done = _chatDone;
    _chatDone = null;
    if (done != null && !done.isCompleted) done.complete();
    setState(() {
      _assistantBusy = false;
      _status = context.strings.statusStopped;
    });
    unawaited(_persist());
  }

  bool get _canRegenerateChat {
    if (!_isChat || _chatLocked || _chat.isEmpty) return false;
    return _chat.last.role == TavernChatRole.assistant;
  }

  /// VN: redo the upcoming beat, or drop the current AI beat (and everything
  /// after it) then write a replacement from that cut point.
  bool get _canRegenerateVn {
    if (_isChat || _runtime.pointer.isEnded) return false;
    if (_streamBeatId != null) return false;
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
    // Cancel in-flight adopt / linear prefetch so a stale reply cannot land.
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
    if (bridge.beatById(beatId) == null) return;

    // Drop this beat and its descendants; keep sibling branches.
    final pruned = bridge.pruneSubtree(beatId);
    _history.truncateFromBeat(beatId);

    final main = _mergeBeats(_baseMain, pruned.generatedBeats);
    final resume = _history.current;
    final runtime = resume == null
        ? MainRuntime(main, save: MainSavePointer(nodeId: nodeId, beatId: ''))
        : MainRuntime(main, save: resume);
    // Always reopen the interval so the next generate replaces the cut beat.
    if (!runtime.needsBridge) {
      runtime.requestBridge();
    }

    final nextBridge = pruned.copyWith(
      nodeId: nodeId,
      turnCount: pruned.turnsForNode(nodeId),
      summary: pruned.generatedBeats
          .where((b) => b.nodeId == nodeId)
          .map((b) => b.lines.map((l) => l.text).join(' '))
          .join(' ')
          .trim(),
    );

    AppLog.instance.info(
      '重新生成：保留 ${pruned.generatedBeats.length} 拍',
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

  void _openVnSettings() {
    pushAppSlide(context, const VnSettingsPage());
  }

  Future<void> _refreshReplyChoices() async {
    if (!mounted || _assistantBusy || _choicesBusy) return;
    if (_chat.isEmpty || _chat.last.role != TavernChatRole.assistant) {
      return;
    }
    setState(() => _choicesBusy = true);
    try {
      final settings = AppScope.settingsOf(context);
      final action = TavernReplyChoiceAction(
        textClient: AppScope.textClientOf(context),
      );
      final choices = await action.generate(
        ctx: settings.textPromptContext(),
        project: _project,
        history: List<TavernChatMessage>.unmodifiable(_chat),
        plotCatalog: settings.plotElements,
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
    _branchSourceBeatId = null;
    _generateEpoch++;
    _generating = false;
    _streamBeatId = null;
    _prefetchPaused = false;
  }

  /// Furthest generated beat ahead of the player (queue tip, else current).
  Beat? get _newestBeat {
    if (_prefetchQueue.isNotEmpty) return _prefetchQueue.last;
    return _runtime.currentBeat;
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

  bool _canLinearPrefetchMore(String nodeId) {
    if (_runtime.pointer.isEnded) return false;
    final node = _runtime.main.nodeById(nodeId);
    if (node == null || node.tags.contains('ending')) return false;
    final newest = _newestBeat;
    // Newest tip already branches — next write is branch batch, not linear.
    if (newest != null && newest.choices.isNotEmpty) return false;
    return true;
  }

  Future<void> _ensureBridge({
    String? linkFromBeatId,
    String? linkChoiceId,
  }) async {
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
        _consumePrefetch(
          fromBeatId: linkFromBeatId,
          choiceId: linkChoiceId,
        );
        _maintainPrefetchBuffer();
        _persist();
        return;
      }
      // A background write may be about to land in the queue; wait for it.
      if (_generating) return;
      await _generateOne(
        adopt: true,
        linkFromBeatId: linkFromBeatId,
        linkChoiceId: linkChoiceId,
      );
      _maintainPrefetchBuffer();
      return;
    }

    if (_shouldMaintainPrefetch) {
      _maintainPrefetchBuffer();
    }
  }

  /// Once the AI interval has started, keep linear buffer or arm branch batch.
  bool get _shouldMaintainPrefetch {
    if (_runtime.pointer.isEnded) return false;
    if (_runtime.needsBridge) return true;
    final bridge = _bridge;
    if (bridge == null) return false;
    if (bridge.generatedBeats.isNotEmpty) return true;
    return _prefetchQueue.isNotEmpty;
  }

  /// Linear fill to 2, or branch-batch when the newest beat has choices.
  Future<void> _maintainPrefetchBuffer() async {
    if (_isChat || !mounted || _generating) return;
    if (!_shouldMaintainPrefetch && !_runtime.needsBridge) return;

    final newest = _newestBeat;
    if (newest != null && newest.choices.isNotEmpty) {
      await _ensureBranchPrefetch(newest);
      return;
    }

    final node = _runtime.currentNode;
    if (node == null) return;
    if (_prefetchQueue.length >= _prefetchTarget) return;
    if (!_canLinearPrefetchMore(node.id)) return;
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
    _maintainPrefetchBuffer();
  }

  /// Grow up to 3 post-choice beats for [source] in one model call.
  Future<void> _ensureBranchPrefetch(Beat source) async {
    if (_isChat || !mounted || _generating) return;
    if (source.choices.isEmpty) return;

    final base = _bridge ?? BridgeSession(nodeId: source.nodeId);
    final requests = <BridgeBranchPrefetchRequest>[];
    for (final choice in source.choices) {
      if (requests.length >= BridgeSession.maxChoicesPerBeat) break;
      if (choice.target.type == TransitionType.end) continue;
      if (base.toBeatId(source.id, choice.id) != null) continue;
      final String targetNodeId;
      if (choice.target.type == TransitionType.beat) {
        targetNodeId = source.nodeId;
      } else if (choice.target.type == TransitionType.node) {
        final id = choice.target.nodeId;
        if (id == null || id.isEmpty) continue;
        targetNodeId = id;
      } else {
        continue;
      }
      requests.add(
        BridgeBranchPrefetchRequest(
          choice: choice,
          targetNodeId: targetNodeId,
        ),
      );
    }

    if (requests.isEmpty) {
      _branchSourceBeatId = source.id;
      return;
    }
    // Already fully armed for this source — do not spam the model.
    if (_branchSourceBeatId == source.id) return;

    final epoch = _generateEpoch;
    setState(() => _generating = true);

    final settings = AppScope.settingsOf(context);
    try {
      final action = BridgeBranchPrefetchAction(
        textClient: AppScope.textClientOf(context),
      );
      final results = await action.generate(
        ctx: settings.textPromptContext(),
        project: _project.copyWith(main: _runtime.main),
        sourceNodeId: source.nodeId,
        session: base,
        branches: requests,
        plotCatalog: settings.plotElements,
        role: _playRole,
        minLines: settings.ai.minBridgeLines,
        inStationChoiceFrequency: settings.ai.inStationChoiceFrequency,
      );
      if (!mounted || epoch != _generateEpoch) return;

      var session = _bridge ?? base;
      var linked = 0;
      for (final row in results) {
        final beat = row.beat;
        if (beat == null) continue;
        session = session
            .withBeat(beat)
            .withBranchEdge(
              fromBeatId: source.id,
              choiceId: row.choiceId,
              toBeatId: beat.id,
            );
        linked++;
      }
      setState(() {
        _bridge = session;
        _generating = false;
        _prefetchPaused = false;
        // Only mark complete when every requested path has a beat.
        _branchSourceBeatId =
            linked >= requests.length ? source.id : null;
      });
      AppLog.instance.info(
        '分支就绪 $linked/${requests.length}',
        tag: 'play.vn',
      );
      await _persist();
    } on AiTextException catch (error) {
      if (!mounted || epoch != _generateEpoch) return;
      setState(() {
        _generating = false;
        _prefetchPaused = true;
        _branchSourceBeatId = null;
      });
      AppLog.instance.warning(
        '分支批写失败：${error.message}',
        tag: 'play.vn',
      );
    } catch (error, stack) {
      if (!mounted || epoch != _generateEpoch) return;
      AppLog.instance.error(
        '分支批写异常',
        tag: 'play.vn',
        error: error,
        stackTrace: stack,
      );
      setState(() {
        _generating = false;
        _prefetchPaused = true;
        _branchSourceBeatId = null;
      });
    }
  }

  void _consumePrefetch({String? fromBeatId, String? choiceId}) {
    if (_prefetchQueue.isEmpty) return;
    final beat = _prefetchQueue.removeAt(0);
    final session = _bridge ?? BridgeSession(nodeId: beat.nodeId);
    AppLog.instance.info(
      '采用预写，缓冲 ${_prefetchQueue.length}',
      tag: 'play.vn',
    );
    _adoptBeat(
      beat,
      session,
      fromBeatId: fromBeatId,
      choiceId: choiceId,
    );
  }

  void _adoptBeat(
    Beat beat,
    BridgeSession session, {
    String? fromBeatId,
    String? choiceId,
  }) {
    setState(() {
      _runtime.adoptBridgeBeat(beat);
      _recordPosition();
      var next = session.withBeat(beat).copyWith(
            nodeId: beat.nodeId,
            turnCount: session.withBeat(beat).turnsForNode(beat.nodeId),
            summary:
                '${session.summary} ${beat.lines.map((l) => l.text).join(' ')}'
                    .trim(),
          );
      if (fromBeatId != null &&
          fromBeatId.isNotEmpty &&
          choiceId != null &&
          choiceId.isNotEmpty) {
        next = next.withBranchEdge(
          fromBeatId: fromBeatId,
          choiceId: choiceId,
          toBeatId: beat.id,
        );
      }
      _bridge = next;
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

  Future<void> _generateOne({
    required bool adopt,
    String? linkFromBeatId,
    String? linkChoiceId,
  }) async {
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
    final client = AppScope.textClientOf(context);
    // The beat the player is waiting for arrives line by line; background
    // prefetch stays buffered (streaming it would show nothing).
    if (adopt && client is AiTextStreamClient) {
      await _streamBeat(
        node: node,
        session: session,
        epoch: epoch,
        linkFromBeatId: linkFromBeatId,
        linkChoiceId: linkChoiceId,
      );
      return;
    }
    try {
      final action = BridgeGenerateAction(textClient: client);
      final beat = await action.generate(
        ctx: settings.textPromptContext(),
        project: _project.copyWith(main: _runtime.main),
        nodeId: node.id,
        session: session,
        plotCatalog: settings.plotElements,
        role: _playRole,
        minLines: settings.ai.minBridgeLines,
        inStationChoiceFrequency: settings.ai.inStationChoiceFrequency,
      );
      if (!mounted || epoch != _generateEpoch) return;
      if (adopt) {
        _adoptBeat(
          beat,
          _bridge ?? BridgeSession(nodeId: node.id),
          fromBeatId: linkFromBeatId,
          choiceId: linkChoiceId,
        );
        await _persist();
      } else {
        setState(() {
          _prefetchQueue.add(beat);
          _generating = false;
        });
        // Also park in the story-tree library (not only the linear queue).
        final parked = (_bridge ?? BridgeSession(nodeId: node.id)).withBeat(beat);
        _bridge = parked;
        AppLog.instance.info(
          '线性预写 ${_prefetchQueue.length}/$_prefetchTarget',
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
        _adoptBeat(
          fallback,
          _bridge ?? BridgeSession(nodeId: node.id),
          fromBeatId: linkFromBeatId,
          choiceId: linkChoiceId,
        );
        setState(() => _status = context.strings.statusSafeExit);
        await _persist();
      } else {
        setState(() {
          _generating = false;
          _prefetchPaused = true;
        });
        AppLog.instance.warning(
          '后台预写失败：${error.message}',
          tag: 'play.vn',
        );
        if (_runtime.needsBridge && _prefetchQueue.isEmpty) {
          _prefetchPaused = false;
          await _generateOne(
            adopt: true,
            linkFromBeatId: linkFromBeatId,
            linkChoiceId: linkChoiceId,
          );
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
        _adoptBeat(
          fallback,
          _bridge ?? BridgeSession(nodeId: node.id),
          fromBeatId: linkFromBeatId,
          choiceId: linkChoiceId,
        );
        setState(() => _status = context.strings.statusSafeExit);
        await _persist();
      } else {
        setState(() {
          _generating = false;
          _prefetchPaused = true;
        });
        if (_runtime.needsBridge && _prefetchQueue.isEmpty) {
          _prefetchPaused = false;
          await _generateOne(
            adopt: true,
            linkFromBeatId: linkFromBeatId,
            linkChoiceId: linkChoiceId,
          );
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

  /// Writes one beat the player is waiting for, showing every line as it
  /// arrives. Errors are handled here so a half-written beat still counts.
  Future<void> _streamBeat({
    required StoryNode node,
    required BridgeSession session,
    required int epoch,
    String? linkFromBeatId,
    String? linkChoiceId,
  }) async {
    final settings = AppScope.settingsOf(context);
    final strings = context.strings;
    final action = BridgeGenerateAction(
      textClient: AppScope.textClientOf(context),
    );
    final beatId = 'bridge_${node.id}_${session.turnCount + 1}';
    Beat? live;

    try {
      await for (final event in action.streamGenerate(
        ctx: settings.textPromptContext(),
        project: _project.copyWith(main: _runtime.main),
        nodeId: node.id,
        session: session,
        plotCatalog: settings.plotElements,
        role: _playRole,
        minLines: settings.ai.minBridgeLines,
        inStationChoiceFrequency: settings.ai.inStationChoiceFrequency,
      )) {
        if (!mounted || epoch != _generateEpoch) return;
        switch (event) {
          case BridgeBeatLineEvent():
            final line = event.line;
            if (live == null) {
              live = Beat(
                id: beatId,
                nodeId: node.id,
                scene: Scene(locationText: event.location),
                appearances: const [],
                lines: <DialogueLine>[line],
                choices: const <Choice>[],
              );
              setState(() {
                _streamBeatId = beatId;
                _runtime.adoptBridgeBeat(live!);
                _recordPosition();
              });
              AppLog.instance.info('流式第一句已上屏', tag: 'play.vn');
            } else {
              // Keep the parked copy in step with the runtime so a mid-stream
              // failure still commits every line the player already saw.
              live = live.copyWith(lines: [...live.lines, line]);
              setState(() => _runtime.appendStreamLine(beatId, line));
            }
          case BridgeBeatDoneEvent():
            final beat = event.beat;
            setState(() {
              if (live == null) {
                // No line ever streamed through (one-shot fallback):
                // enter the finished beat directly.
                _runtime.adoptBridgeBeat(beat);
                _recordPosition();
              } else {
                _runtime.updateBeat(beat);
              }
              _streamBeatId = null;
              _generating = false;
              _prefetchPaused = false;
              _status = null;
            });
            AppLog.instance.info(
              '流式本拍完成：${beat.lines.length} 句',
              tag: 'play.vn',
            );
            await _commitStreamedBeat(
              beat,
              session,
              fromBeatId: linkFromBeatId,
              choiceId: linkChoiceId,
            );
        }
      }
    } on AiTextException catch (error) {
      if (!mounted || epoch != _generateEpoch) return;
      await _finishStreamedFailure(
        error.message,
        live: live,
        node: node,
        session: session,
        fromBeatId: linkFromBeatId,
        choiceId: linkChoiceId,
      );
    } catch (error, stack) {
      if (!mounted || epoch != _generateEpoch) return;
      AppLog.instance.error(
        '流式本拍异常',
        tag: 'play.vn',
        error: error,
        stackTrace: stack,
      );
      await _finishStreamedFailure(
        strings.statusTurnFailed,
        live: live,
        node: node,
        session: session,
        fromBeatId: linkFromBeatId,
        choiceId: linkChoiceId,
      );
    }
  }

  /// Parks a finished beat in the session (story tree, summary, branch edge).
  Future<void> _commitStreamedBeat(
    Beat beat,
    BridgeSession session, {
    String? fromBeatId,
    String? choiceId,
  }) async {
    final withBeat = session.withBeat(beat);
    var next = withBeat.copyWith(
      nodeId: beat.nodeId,
      turnCount: withBeat.turnsForNode(beat.nodeId),
      summary:
          '${session.summary} ${beat.lines.map((l) => l.text).join(' ')}'
              .trim(),
    );
    if (fromBeatId != null &&
        fromBeatId.isNotEmpty &&
        choiceId != null &&
        choiceId.isNotEmpty) {
      next = next.withBranchEdge(
        fromBeatId: fromBeatId,
        choiceId: choiceId,
        toBeatId: beat.id,
      );
    }
    _bridge = next;
    await _persist();
    _maintainPrefetchBuffer();
  }

  /// Stream died: keep the lines already on screen, or fall back when none
  /// arrived.
  Future<void> _finishStreamedFailure(
    String message, {
    required Beat? live,
    required StoryNode node,
    required BridgeSession session,
    String? fromBeatId,
    String? choiceId,
  }) async {
    final beat = live;
    if (beat == null) {
      final fallback = _fallbackBeat(
        nodeId: node.id,
        turn: session.turnCount + 1,
        text: message,
      );
      _adoptBeat(
        fallback,
        _bridge ?? BridgeSession(nodeId: node.id),
        fromBeatId: fromBeatId,
        choiceId: choiceId,
      );
      setState(() {
        _streamBeatId = null;
        _generating = false;
        _status = context.strings.statusSafeExit;
      });
      await _persist();
      return;
    }

    setState(() {
      _streamBeatId = null;
      _generating = false;
      _status = message;
    });
    AppLog.instance.warning(
      '流式中断，保留已出现的 ${beat.lines.length} 句',
      tag: 'play.vn',
    );
    await _commitStreamedBeat(
      beat,
      session,
      fromBeatId: fromBeatId,
      choiceId: choiceId,
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
    final settings = AppScope.settingsOf(context);
    return AppPage(
      title: title,
      // VN plays full-bleed: no software title bar, controls sit under the box.
      showTitle: chatMode,
      // Stage art runs under the window title band / status bar too.
      background: chatMode
          ? null
          : _VnBackground(
              key: vnBackdropKey,
              project: _project,
              projectDir: _projectDir,
              backgroundAssetId: _runtime.resolvedBackgroundAssetId,
            ),
      // Chat keeps a quieter header than other large page titles.
      titleWidget: chatMode
          ? AppText(
              title,
              role: AppTextRole.subtitle,
              maxLines: 1,
            )
          : null,
      onBack: chatMode ? () => Navigator.of(context).maybePop() : null,
      actions: [
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
                    onStop: _assistantBusy ? _stopChatStream : null,
                  ),
                ),
              ],
            )
          : ListenableBuilder(
              listenable: settings,
              builder: (context, _) => _VnStage(
                runtime: _runtime,
                project: _project,
                projectDir: _projectDir,
                settings: settings.vnUi,
                speakerLabel: _speakerLabel,
                isNarration: _isNarration,
                // Errors / soft notices only — never the writing placeholder.
                status: _status,
                centerActions: _centerActions(),
                canBack: _history.canBack,
                canForward: _history.canForward || _canContinueStory,
                canFastForward: _history.canForward,
                fastForwarding: _fastForwardTimer != null,
                canRegenerate: _canRegenerateVn,
                generating: _generating,
                streaming: _streamBeatId != null,
                revealInstant:
                    _history.canForward || _fastForwardTimer != null,
                onStageTap: _onStageTap,
                onBack: _goBack,
                onForward: _forward,
                onFastForward: _fastForwardTimer != null
                    ? _stopFastForward
                    : _startFastForward,
                onRegenerate: _regenerateVnSegment,
                onSettings: _openVnSettings,
                onExit: () => Navigator.of(context).maybePop(),
              ),
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

class _VnStage extends StatefulWidget {
  const _VnStage({
    required this.runtime,
    required this.project,
    required this.projectDir,
    required this.settings,
    required this.speakerLabel,
    required this.isNarration,
    required this.status,
    required this.centerActions,
    required this.canBack,
    required this.canForward,
    required this.canFastForward,
    required this.fastForwarding,
    required this.canRegenerate,
    required this.generating,
    required this.streaming,
    required this.revealInstant,
    required this.onStageTap,
    required this.onBack,
    required this.onForward,
    required this.onFastForward,
    required this.onRegenerate,
    required this.onSettings,
    required this.onExit,
  });

  final MainRuntime runtime;
  final Project project;
  final String? projectDir;
  final VnUiSettings settings;
  final String? Function(DialogueLine) speakerLabel;
  final bool Function(DialogueLine) isNarration;
  final String? status;
  final List<_VnCenterAction> centerActions;
  final bool canBack;
  final bool canForward;
  final bool canFastForward;
  final bool fastForwarding;
  final bool canRegenerate;
  final bool generating;

  /// The current beat is still arriving from the model.
  final bool streaming;

  /// Replaying recorded lines: show text without the typewriter.
  final bool revealInstant;
  final VoidCallback onStageTap;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onFastForward;
  final VoidCallback onRegenerate;
  final VoidCallback onSettings;
  final VoidCallback onExit;

  @override
  State<_VnStage> createState() => _VnStageState();
}

class _VnStageState extends State<_VnStage> {
  /// Page of the current line on screen (0-based).
  int _page = 0;
  List<String> _pages = const <String>[];
  Object? _pagesKey;

  /// Answers「this page still being written?」for the tap handler.
  final TypewriterHandle _typing = TypewriterHandle();

  String? get _placeholder {
    final runtime = widget.runtime;
    if (runtime.pointer.isEnded) return context.strings.segmentEnded;
    if (runtime.currentLine != null) return null;
    if (runtime.pointer.phase == PlayPhase.choices) {
      return context.strings.choosePlease;
    }
    // Waiting for the next beat: keep the box quiet.
    return '…';
  }

  /// Splits the current line into fixed-line pages (cached per geometry).
  List<String> _paginate({
    required Object sourceKey,
    required String text,
    required TextStyle style,
    required double width,
    required int lines,
    required double fontSize,
    required TextScaler scaler,
  }) {
    if (text.trim().isEmpty) {
      _pages = const <String>[];
      _pagesKey = null;
      _page = 0;
      return _pages;
    }
    final key = (
      sourceKey,
      text,
      width.round(),
      lines,
      fontSize,
      scaler.scale(10).round(),
    );
    if (key != _pagesKey) {
      _pagesKey = key;
      _pages = paginateText(
        text,
        style: style,
        maxWidth: width,
        maxLines: lines,
        textScaler: scaler,
      );
      _page = 0;
    }
    return _pages;
  }

  /// Turns to the next page of the current line; false when it is the last.
  bool _turnPage() {
    if (_page + 1 >= _pages.length) return false;
    setState(() => _page++);
    return true;
  }

  void _handleTap() {
    // Still revealing this page: the first tap only finishes it.
    if (!_typing.isDone) {
      _typing.complete();
      return;
    }
    if (_turnPage()) return;
    widget.onStageTap();
  }

  void _handleForward() {
    if (!_typing.isDone) {
      _typing.complete();
      return;
    }
    if (_turnPage()) return;
    widget.onForward();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.runtime;
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final ended = runtime.pointer.isEnded;
    final line = ended ? null : runtime.currentLine;
    final showChoices = widget.centerActions.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Very short viewports: keep the dialogue readable, drop the controls.
        final showControls = constraints.maxHeight >= 260;
        final controlsHeight = showControls
            ? AppTheme.vnControlSize + AppTheme.vnControlGap
            : 0.0;
        final statusHeight = widget.status == null
            ? 0.0
            : AppTheme.spaceSm + 20;
        final panelWidth = math.max(
          0.0,
          constraints.maxWidth - AppTheme.pagePadding * 2,
        );
        final available =
            constraints.maxHeight -
            AppTheme.vnStageBottomGap -
            bottomInset -
            controlsHeight -
            statusHeight;
        final linePx = widget.settings.fontSize * AppDialogueChrome.lineHeight;
        final bodyRoom =
            available -
            AppDialogueChrome.headerHeight -
            AppDialogueChrome.padding.vertical;
        final fitLines = bodyRoom <= 0 ? 1 : (bodyRoom / linePx).floor();
        final lines = fitLines.clamp(1, widget.settings.lines);

        final narration = line != null && widget.isNarration(line);
        final body = line == null ? '' : stripDialogueSpeakerLabel(line.text);
        final beat = runtime.currentBeat;
        // Last line of a beat the model is still writing: wait for more.
        final atStreamTail = widget.streaming &&
            beat != null &&
            runtime.pointer.lineIndex >= beat.lines.length - 1;
        final textColor = tryParseHexColor(widget.settings.textHex);
        final bodyStyle = AppDialogueChrome.bodyStyle(
          context,
          widget.settings.fontSize,
          italic: narration,
          color: textColor,
        );
        final pages = _paginate(
          sourceKey: line?.id ?? (ended ? 'ended' : 'empty'),
          text: body,
          style: bodyStyle,
          width: AppDialogueChrome.textWidth(panelWidth),
          lines: lines,
          fontSize: widget.settings.fontSize,
          scaler: MediaQuery.textScalerOf(context),
        );
        final pageIndex = pages.isEmpty ? 0 : _page.clamp(0, pages.length - 1);
        final pageText = pages.isEmpty ? null : pages[pageIndex];
        final speaker = line == null ? null : widget.speakerLabel(line);
        // Everything the portrait must stand on: the reading box, the control
        // bar under it, and the gap below the controls.
        final stageFloor = AppTheme.vnStageBottomGap +
            bottomInset +
            controlsHeight +
            statusHeight +
            AppDialogueChrome.panelHeight(
              lines: lines,
              fontSize: widget.settings.fontSize,
            );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Portrait stops at the box's top edge, so its feet meet the
              // frosted glass instead of standing behind it.
              if (!showChoices)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: stageFloor,
                  child: _VnSpeakerSprite(
                    project: widget.project,
                    projectDir: widget.projectDir,
                    line: line,
                    appearances: runtime.appearances,
                  ),
                ),
              Column(
                children: [
                  Expanded(
                    child: showChoices
                        ? _VnChoiceOverlay(actions: widget.centerActions)
                        : const SizedBox.expand(),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      0,
                      AppTheme.pagePadding,
                      AppTheme.vnStageBottomGap + bottomInset,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.status != null) ...[
                          AppText(
                            widget.status!,
                            role: AppTextRole.caption,
                            maxLines: 2,
                          ),
                          const SizedBox(height: AppTheme.spaceSm),
                        ],
                        AppDialoguePanel(
                          lines: lines,
                          fontSize: widget.settings.fontSize,
                          backgroundHex: widget.settings.backgroundHex,
                          opacity: widget.settings.opacity,
                          header: speaker == null
                              ? null
                              : AppText(
                                  speaker,
                                  role: AppTextRole.label,
                                  color: textColor ?? scheme.primary,
                                  fontWeight: FontWeight.w700,
                                  maxLines: 1,
                                ),
                          trailing: pages.length > 1
                              ? AppText(
                                  '${pageIndex + 1}/${pages.length}',
                                  role: AppTextRole.caption,
                                  color: scheme.onSurfaceVariant,
                                )
                              : (atStreamTail
                                  ? AppText(
                                      '…',
                                      role: AppTextRole.caption,
                                      color: scheme.onSurfaceVariant,
                                    )
                                  : null),
                          child: pageText == null
                              ? Text(
                                  _placeholder ?? '',
                                  style: AppDialogueChrome.bodyStyle(
                                    context,
                                    widget.settings.fontSize,
                                    italic: true,
                                    color: textColor,
                                  ),
                                  maxLines: lines,
                                  overflow: TextOverflow.clip,
                                )
                              : AppTypewriterText(
                                  text: pageText,
                                  handle: _typing,
                                  charsPerSecond: widget.revealInstant
                                      ? 0
                                      : widget.settings.textSpeed,
                                  style: AppDialogueChrome.bodyStyle(
                                    context,
                                    widget.settings.fontSize,
                                    italic: narration,
                                    color: textColor,
                                  ),
                                  maxLines: lines,
                                ),
                        ),
                        if (showControls) ...[
                          const SizedBox(height: AppTheme.vnControlGap),
                          _VnControlBar(
                            canBack: widget.canBack,
                            canForward: widget.canForward,
                            canFastForward: widget.canFastForward,
                            fastForwarding: widget.fastForwarding,
                            canRegenerate: widget.canRegenerate,
                            generating: widget.generating,
                            onExit: widget.onExit,
                            onBack: widget.onBack,
                            onForward: _handleForward,
                            onFastForward: widget.onFastForward,
                            onRegenerate: widget.onRegenerate,
                            onSettings: widget.onSettings,
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

/// Stage control bar: exit, history, regenerate, reading settings.
class _VnControlBar extends StatelessWidget {
  const _VnControlBar({
    required this.canBack,
    required this.canForward,
    required this.canFastForward,
    required this.fastForwarding,
    required this.canRegenerate,
    required this.generating,
    required this.onExit,
    required this.onBack,
    required this.onForward,
    required this.onFastForward,
    required this.onRegenerate,
    required this.onSettings,
  });

  final bool canBack;

  /// Forward can also keep the story going at the newest progress.
  final bool canForward;

  /// Fast-forward only replays recorded lines, so it needs history ahead.
  final bool canFastForward;
  final bool fastForwarding;
  final bool canRegenerate;

  /// Writing in flight: the regenerate slot shows a ring instead.
  final bool generating;
  final VoidCallback onExit;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onFastForward;
  final VoidCallback onRegenerate;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    Widget button({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) => AppIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      size: AppTheme.vnControlSize,
      iconSize: AppTheme.vnControlIconSize,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppTheme.spaceXs,
      runSpacing: AppTheme.spaceXs,
      children: [
        button(
          icon: Icons.arrow_back,
          tooltip: context.ui.back,
          onPressed: onExit,
        ),
        button(
          icon: Icons.skip_previous_rounded,
          tooltip: strings.historyBack,
          onPressed: canBack ? onBack : null,
        ),
        button(
          icon: Icons.skip_next_rounded,
          tooltip: strings.historyForward,
          onPressed: canForward ? onForward : null,
        ),
        button(
          icon: fastForwarding
              ? Icons.pause_rounded
              : Icons.fast_forward_rounded,
          tooltip: strings.historyFastForward,
          onPressed: canFastForward || fastForwarding ? onFastForward : null,
        ),
        if (generating)
          SizedBox(
            width: AppTheme.vnControlSize,
            height: AppTheme.vnControlSize,
            child: Center(
              child: AppBusyIndicator(
                padding: EdgeInsets.zero,
                semanticLabel: strings.generatingSegment,
              ),
            ),
          )
        else
          button(
            icon: Icons.refresh_rounded,
            tooltip: strings.regenerateSegment,
            onPressed: canRegenerate ? onRegenerate : null,
          ),
        button(
          icon: Icons.settings_outlined,
          tooltip: strings.vnSettingsTitle,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

/// Full-bleed stage art, painted by [AppPage] behind the window/status chrome
/// as well as the body. Missing asset = plain canvas.
class _VnBackground extends StatelessWidget {
  const _VnBackground({
    super.key,
    required this.project,
    required this.projectDir,
    required this.backgroundAssetId,
  });

  final Project project;
  final String? projectDir;
  final String? backgroundAssetId;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(color: Theme.of(context).colorScheme.surface);
    final file = _vnAssetFile(
      project: project,
      projectDir: projectDir,
      assetId: backgroundAssetId,
    );
    if (file == null) return fallback;
    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

/// Standing portrait for the current speaker (avatar / sprite asset).
class _VnSpeakerSprite extends StatelessWidget {
  const _VnSpeakerSprite({
    required this.project,
    required this.projectDir,
    required this.line,
    required this.appearances,
  });

  final Project project;
  final String? projectDir;
  final DialogueLine? line;
  final List<Appearance> appearances;

  String? get _speakerId {
    final speakerId = line?.speakerId?.trim();
    if (speakerId == null || speakerId.isEmpty) return null;
    if (line?.kind == DialogueKind.narration) return null;
    return speakerId;
  }

  String? _resolvedAssetId(String speakerId) {
    for (final appearance in appearances) {
      if (appearance.characterId != speakerId) continue;
      final sprite = appearance.spriteAssetId?.trim();
      if (sprite != null && sprite.isNotEmpty) return sprite;
    }

    final member = project.castById(speakerId);
    final avatar = member?.avatarAssetId?.trim();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    return null;
  }

  AppearanceSlot _resolvedSlot(String speakerId) {
    for (final appearance in appearances) {
      if (appearance.characterId != speakerId) continue;
      final slot = appearance.slot;
      if (slot != null) return slot;
    }
    return project.castById(speakerId)?.preferredSlot ?? AppearanceSlot.left;
  }

  Alignment _alignFor(AppearanceSlot slot) => switch (slot) {
    AppearanceSlot.left => Alignment.bottomLeft,
    AppearanceSlot.right => Alignment.bottomRight,
    AppearanceSlot.center => Alignment.bottomCenter,
  };

  @override
  Widget build(BuildContext context) {
    final speakerId = _speakerId;
    if (speakerId == null) return const SizedBox.shrink();
    final file = _vnAssetFile(
      project: project,
      projectDir: projectDir,
      assetId: _resolvedAssetId(speakerId),
    );
    if (file == null) return const SizedBox.shrink();

    final slot = _resolvedSlot(speakerId);
    final align = _alignFor(slot);
    final sidePad = slot == AppearanceSlot.center ? 0.0 : AppTheme.pagePadding;

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(
          left: slot == AppearanceSlot.right ? 0 : sidePad,
          right: slot == AppearanceSlot.left ? 0 : sidePad,
        ),
        child: Align(
          alignment: align,
          child: FractionallySizedBox(
            heightFactor: 1,
            widthFactor: slot == AppearanceSlot.center ? 0.72 : 0.52,
            alignment: align,
            child: Image.file(
              file,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

File? _vnAssetFile({
  required Project project,
  required String? projectDir,
  required String? assetId,
}) {
  final id = assetId?.trim();
  final dir = projectDir;
  if (id == null || id.isEmpty || dir == null || dir.isEmpty) return null;
  final asset = project.assetById(id);
  if (asset == null) return null;
  final file = File(ProjectAssetFiles.absolutePath(dir, asset.relativePath));
  if (!file.existsSync()) return null;
  return file;
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
