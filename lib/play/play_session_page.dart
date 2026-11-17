import 'package:anoworld/app/app_scope.dart';
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
import 'package:anoworld/foundation/widgets/app_surface.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/play_chat_message.dart';
import 'package:anoworld/play/play_chat_view.dart';
import 'package:anoworld/settings/ai_model_picker.dart';
import 'package:anoworld/settings/settings_page.dart';
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
    return name.isNotEmpty ? name : '我';
  }

  String get _assistantLabel {
    for (final member in _project.cast) {
      if (member.isProtagonist) return member.name;
    }
    if (_project.cast.isNotEmpty) return _project.cast.first.name;
    return '角色';
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
        setState(() => _status = '已读取进度');
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

  String _speakerName(DialogueLine line) {
    if (line.kind == DialogueKind.narration || line.speakerId == null) {
      return '旁白';
    }
    final member = _project.castById(line.speakerId!);
    return member?.name ?? line.speakerId!;
  }

  String _castName(String characterId) {
    return _project.castById(characterId)?.name ?? characterId;
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
      _status = '正在写这一段…';
    });

    final settings = AppScope.settingsOf(context);
    final ctx = settings.textPromptContext();
    try {
      final action = TavernChatGenerateAction(
        textClient: AppScope.textClientOf(context),
      );
      final content = await action.generate(
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
            content: content,
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
        _status = '这一轮暂时写不出来，请稍后再试';
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
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsPage(),
      ),
    );
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
    if (_bridge == null || _bridge!.nodeId != nodeId) {
      _bridge = BridgeSession(nodeId: nodeId);
    }
  }

  void _restart() {
    setState(() {
      _runtime = MainRuntime(_baseMain);
      _bridge = null;
      _chat.clear();
      _replyChoices = const [];
      _status = '已从头开始';
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
      _status = '正在写这一段…';
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
        _status = '用稳妥出口继续';
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
        lines: const [
          DialogueLine(
            id: 'bridge_fallback_l0',
            text: '这一段暂时写不出来，可以先用下方选项继续',
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
        _status = '用稳妥出口继续';
      });
      await _persist();
    }
  }

  List<Widget> _fallbackExitButtons() {
    final outs = _runtime.outboundFromCurrent();
    if (outs.isEmpty) return const [];
    return [
      for (final edge in outs)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: AppButton(
            label:
                '前往：${_runtime.main.nodeById(edge.to)?.title ?? edge.to}',
            onPressed: _busy
                ? null
                : () {
                    setState(() => _runtime.jumpToNode(edge.to));
                    _syncBridgeNode();
                    _persist();
                    _ensureBridge();
                  },
            variant: AppButtonVariant.ghost,
            expanded: true,
          ),
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
                tooltip: '重新生成回复',
                onPressed: _regenerateLastAssistant,
              ),
            ]
          : const [],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          if (chatMode) {
            return Column(
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
            );
          }
          return Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_status != null) ...[
                  AppText(_status!, role: AppTextRole.caption),
                  const SizedBox(height: AppTheme.spaceSm),
                ],
                Expanded(
                  child: _VnStage(
                    runtime: _runtime,
                    speakerName: _speakerName,
                    castName: _castName,
                    onAdvance: _advance,
                    narrow: narrow,
                    bridging: _busy,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                if (_runtime.pointer.phase == PlayPhase.choices)
                  ..._runtime.visibleChoices.map(
                    (choice) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppTheme.spaceSm,
                      ),
                      child: AppButton(
                        label: choice.text,
                        onPressed: () => _choose(choice),
                        variant: AppButtonVariant.secondary,
                        expanded: true,
                      ),
                    ),
                  )
                else if (_runtime.pointer.isEnded) ...[
                  const AppText('本段结束', role: AppTextRole.subtitle),
                  const SizedBox(height: AppTheme.spaceSm),
                  AppButton(
                    label: '重新开始',
                    onPressed: _restart,
                    expanded: true,
                  ),
                ] else if (_runtime.needsBridge || _busy)
                  AppButton(
                    label: _busy ? '生成中…' : '生成这一段',
                    onPressed: _busy ? null : _ensureBridge,
                    expanded: true,
                  )
                else
                  AppButton(
                    label: '继续',
                    onPressed: _runtime.canAdvance ? _advance : null,
                    expanded: true,
                  ),
                if (!_runtime.pointer.isEnded) ..._fallbackExitButtons(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VnStage extends StatelessWidget {
  const _VnStage({
    required this.runtime,
    required this.speakerName,
    required this.castName,
    required this.onAdvance,
    required this.narrow,
    required this.bridging,
  });

  final MainRuntime runtime;
  final String Function(DialogueLine) speakerName;
  final String Function(String) castName;
  final VoidCallback onAdvance;
  final bool narrow;
  final bool bridging;

  @override
  Widget build(BuildContext context) {
    final line = runtime.currentLine;
    final location = runtime.locationText;
    final appearances = runtime.appearances;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: runtime.canAdvance ? onAdvance : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  runtime.currentNode?.title ??
                      (location?.isNotEmpty == true ? location! : '场景'),
                  role: AppTextRole.subtitle,
                  maxLines: 1,
                ),
                const SizedBox(height: AppTheme.spaceXs),
                AppText(
                  runtime.resolvedBackgroundAssetId == null
                      ? '（无背景图，占位）'
                      : '背景：${runtime.resolvedBackgroundAssetId}',
                  role: AppTextRole.caption,
                  maxLines: 1,
                ),
                if (appearances.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  AppText(
                    appearances
                        .map((a) {
                          final slot = a.slot?.name;
                          final name = castName(a.characterId);
                          return slot == null ? name : '$name（$slot）';
                        })
                        .join(narrow ? ' · ' : '  ·  '),
                    role: AppTextRole.caption,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (line != null) ...[
                      AppText(
                        speakerName(line),
                        role: AppTextRole.label,
                        maxLines: 1,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      AppText(
                        stripDialogueSpeakerLabel(line.text),
                        role: AppTextRole.body,
                      ),
                    ] else if (runtime.pointer.phase == PlayPhase.choices)
                      const AppText('请选择', role: AppTextRole.body)
                    else if (runtime.needsBridge || bridging)
                      AppText(
                        bridging ? '正在写这一段…' : '这一站的过程还没写，点下方生成',
                        role: AppTextRole.body,
                      )
                    else if (runtime.pointer.isEnded)
                      const AppText('……', role: AppTextRole.body)
                    else
                      const AppText('…', role: AppTextRole.body),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
