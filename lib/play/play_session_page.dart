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
import 'package:anoworld/domain/runtime/play_pointer.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
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
  bool _busy = false;
  bool _assistantBusy = false;
  bool _choicesBusy = false;

  /// Tavern chat transcript (chat mode only).
  final List<TavernChatMessage> _chat = <TavernChatMessage>[];
  List<String> _replyChoices = const <String>[];

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
        await _persist();
        await _ensureBridge();
      });
    }
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
    );
  }

  void _advance() {
    if (!_runtime.canAdvance) return;
    setState(() => _runtime.advance());
    _persist();
    _ensureBridge();
  }

  void _choose(Choice choice) {
    setState(() => _runtime.choose(choice.id));
    _syncBridgeNode();
    _persist();
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
    // Keep every generated beat for rollback; reset interval counters only.
    _bridge = current.copyWith(
      nodeId: nodeId,
      turnCount: current.turnsForNode(nodeId),
      summary: '',
    );
  }

  void _restart() {
    setState(() {
      _runtime = MainRuntime(_baseMain);
      _bridge = null;
      _chat.clear();
      _replyChoices = const [];
      _status = context.strings.statusRestarted;
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

  Future<void> _ensureBridge() async {
    if (_isChat || !mounted || _busy) return;
    if (!_runtime.needsBridge) return;

    final node = _runtime.currentNode;
    if (node == null) return;

    if (node.tags.contains('ending')) {
      setState(_runtime.endStory);
      await _persist();
      return;
    }

    _syncBridgeNode();
    final session = _bridge ?? BridgeSession(nodeId: node.id);

    setState(() {
      _busy = true;
      _status = context.strings.statusWriting;
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
      );
      if (!mounted) return;
      setState(() {
        _runtime.adoptBridgeBeat(beat);
        _bridge = session.copyWith(
          generatedBeats: [...session.generatedBeats, beat],
          turnCount: session.turnCount + 1,
          summary:
              '${session.summary} ${beat.lines.map((l) => l.text).join(' ')}'
                  .trim(),
        );
        _busy = false;
        _status = null;
      });
      await _persist();
    } on AiTextException catch (error) {
      if (!mounted) return;
      final choices = BridgeGenerateAction.fallbackChoices(
        _runtime.main,
        node.id,
      );
      final beat = Beat(
        id: 'bridge_fallback_${session.turnCount + 1}',
        nodeId: node.id,
        scene: const Scene(),
        appearances: const [],
        lines: [
          DialogueLine(
            id: 'bridge_fallback_l0',
            text: error.message,
            kind: DialogueKind.narration,
          ),
        ],
        choices: choices,
      );
      setState(() {
        _runtime.adoptBridgeBeat(beat);
        _bridge = session.copyWith(
          generatedBeats: [...session.generatedBeats, beat],
          turnCount: session.turnCount + 1,
        );
        _busy = false;
        _status = context.strings.statusSafeExit;
      });
      await _persist();
    } catch (_) {
      if (!mounted) return;
      final choices = BridgeGenerateAction.fallbackChoices(
        _runtime.main,
        node.id,
      );
      final beat = Beat(
        id: 'bridge_fallback_${session.turnCount + 1}',
        nodeId: node.id,
        scene: const Scene(),
        appearances: const [],
        lines: [
          DialogueLine(
            id: 'bridge_fallback_l0',
            text: context.strings.fallbackBeatText,
            kind: DialogueKind.narration,
          ),
        ],
        choices: choices,
      );
      setState(() {
        _runtime.adoptBridgeBeat(beat);
        _bridge = session.copyWith(
          generatedBeats: [...session.generatedBeats, beat],
          turnCount: session.turnCount + 1,
        );
        _busy = false;
        _status = context.strings.statusSafeExit;
      });
      await _persist();
    }
  }

  List<_VnCenterAction> _centerActions() {
    if (_busy) return const [];
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
            setState(() => _runtime.jumpToNode(edge.to));
            _syncBridgeNode();
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
      actions: chatMode && _canRegenerateChat
          ? [
              AppCircleButton(
                icon: Icons.refresh_rounded,
                tooltip: context.strings.regenerateReply,
                onPressed: _regenerateLastAssistant,
              ),
            ]
          : const [],
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
              status: _status,
              bridging: _busy,
              centerActions: _centerActions(),
              onAdvance: _advance,
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
    required this.bridging,
    required this.centerActions,
    required this.onAdvance,
  });

  final MainRuntime runtime;
  final String? Function(DialogueLine) speakerLabel;
  final bool Function(DialogueLine) isNarration;
  final String? status;
  final bool bridging;
  final List<_VnCenterAction> centerActions;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final line = runtime.currentLine;
    final showChoices = centerActions.isNotEmpty;
    final canTapAdvance = runtime.canAdvance && !showChoices && !bridging;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canTapAdvance ? onAdvance : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _VnBackground(),
          if (showChoices)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              // Keep choices above the dialogue band (SLG layout).
              bottom: 160 + bottomInset,
              child: _VnChoiceOverlay(actions: centerActions),
            ),
          Positioned(
            left: AppTheme.pagePadding,
            right: AppTheme.pagePadding,
            bottom: AppTheme.pagePadding + bottomInset,
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
                if (runtime.needsBridge || bridging) {
                  return bridging
                      ? strings.statusWriting
                      : strings.segmentNotWritten;
                }
                return '…';
              }(),
              status: status,
            ),
          ),
        ],
      ),
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
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePadding,
            ),
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
    );
  }
}
