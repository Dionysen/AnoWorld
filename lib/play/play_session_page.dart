import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/main_runtime.dart';
import 'package:anoworld/domain/runtime/play_pointer.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_surface.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

enum PlayViewMode { visualNovel, chat }

/// Dual-mode runtime sharing one [MainRuntime] pointer + optional bridge AI.
class PlaySessionPage extends StatefulWidget {
  const PlaySessionPage({
    super.key,
    required this.project,
    this.resumeSave = true,
    this.initialSave,
  });

  final Project project;
  final bool resumeSave;
  final MainSavePointer? initialSave;

  @override
  State<PlaySessionPage> createState() => _PlaySessionPageState();
}

class _PlaySessionPageState extends State<PlaySessionPage> {
  late MainRuntime _runtime;
  BridgeSession? _bridge;
  PlayViewMode _mode = PlayViewMode.visualNovel;
  String? _status;
  bool _bootstrapped = false;
  bool _bridging = false;

  Project get _project => widget.project;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _runtime = MainRuntime(widget.project.main, save: widget.initialSave);
    if (widget.resumeSave && widget.initialSave == null) {
      _maybeLoadAutoSave();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBridge());
    }
  }

  Future<void> _maybeLoadAutoSave() async {
    final slot = await AppScope.savesOf(context).load(widget.project.meta.id);
    if (!mounted) return;
    if (slot != null) {
      var main = widget.project.main;
      final bridge = slot.bridge;
      if (bridge != null && bridge.generatedBeats.isNotEmpty) {
        main = _mergeBeats(main, bridge.generatedBeats);
        _bridge = bridge;
      }
      _runtime = MainRuntime(main, save: slot.pointer);
      setState(() => _status = '已读取进度');
    }
    await _ensureBridge();
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

  Future<void> _save() async {
    await AppScope.savesOf(context).save(
      projectId: widget.project.meta.id,
      pointer: _runtime.toSave(),
      bridge: _bridge,
    );
    if (!mounted) return;
    setState(() => _status = '进度已保存');
  }

  void _advance() {
    if (!_runtime.canAdvance) return;
    setState(_runtime.advance);
    _ensureBridge();
  }

  void _choose(Choice choice) {
    setState(() => _runtime.choose(choice.id));
    _syncBridgeNode();
    _ensureBridge();
  }

  void _syncBridgeNode() {
    final nodeId = _runtime.pointer.nodeId;
    if (_bridge == null || _bridge!.nodeId != nodeId) {
      _bridge = BridgeSession(nodeId: nodeId);
    }
  }

  void _restart() {
    setState(() {
      _runtime = MainRuntime(widget.project.main);
      _bridge = null;
      _status = '已从头开始';
    });
    _ensureBridge();
  }

  Future<void> _ensureBridge() async {
    if (!mounted || _bridging) return;
    if (!_runtime.needsBridge) return;

    final node = _runtime.currentNode;
    if (node == null) return;

    if (node.tags.contains('ending')) {
      setState(_runtime.endStory);
      return;
    }

    _syncBridgeNode();
    final session = _bridge ?? BridgeSession(nodeId: node.id);

    setState(() {
      _bridging = true;
      _status = '正在写这一段…';
    });

    final endpoint = AppScope.settingsOf(context).ai.text;
    try {
      final action = BridgeGenerateAction(
        textClient: AppScope.textClientOf(context),
      );
      final beat = await action.generate(
        endpoint: endpoint,
        project: Project(
          meta: _project.meta,
          presets: _project.presets,
          activePresetId: _project.activePresetId,
          background: _project.background,
          cast: _project.cast,
          main: _runtime.main,
          side: _project.side,
          assets: _project.assets,
        ),
        nodeId: node.id,
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _runtime.adoptBridgeBeat(beat);
        _bridge = session.copyWith(
          generatedBeats: [...session.generatedBeats, beat],
          turnCount: session.turnCount + 1,
          summary: '${session.summary} ${beat.lines.map((l) => l.text).join(' ')}'
              .trim(),
        );
        _bridging = false;
        _status = null;
      });
    } on AiTextException catch (error) {
      if (!mounted) return;
      // Fall back to guaranteed exit choices as a synthetic beat.
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
        _bridging = false;
        _status = '用稳妥出口继续';
      });
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
            text: '这一段暂时写不出来，可以先去下一站',
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
        _bridging = false;
        _status = '用稳妥出口继续';
      });
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
            onPressed: _bridging
                ? null
                : () {
                    setState(() => _runtime.jumpToNode(edge.to));
                    _syncBridgeNode();
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
    return AppPage(
      title: '游玩 · ${widget.project.meta.title}',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.save_outlined,
          tooltip: '保存进度',
          onPressed: _runtime.pointer.isEnded ? null : _save,
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          return Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSegmented<PlayViewMode>(
                  value: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                  options: const [
                    AppSegmentOption(
                      value: PlayViewMode.visualNovel,
                      label: '视觉小说',
                      icon: Icons.auto_stories_outlined,
                    ),
                    AppSegmentOption(
                      value: PlayViewMode.chat,
                      label: '聊天',
                      icon: Icons.chat_bubble_outline,
                    ),
                  ],
                ),
                if (_status != null) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  AppText(_status!, role: AppTextRole.caption),
                ],
                const SizedBox(height: AppTheme.spaceMd),
                Expanded(
                  child: _mode == PlayViewMode.visualNovel
                      ? _VnStage(
                          runtime: _runtime,
                          speakerName: _speakerName,
                          castName: _castName,
                          onAdvance: _advance,
                          narrow: narrow,
                          bridging: _bridging,
                        )
                      : _ChatStage(
                          runtime: _runtime,
                          speakerName: _speakerName,
                          onAdvance: _advance,
                        ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                if (_runtime.pointer.phase == PlayPhase.choices)
                  ..._runtime.visibleChoices.map(
                    (choice) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
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
                ] else if (_runtime.needsBridge || _bridging)
                  AppButton(
                    label: _bridging ? '生成中…' : '生成这一段',
                    onPressed: _bridging ? null : _ensureBridge,
                    expanded: true,
                  )
                else
                  AppButton(
                    label: _mode == PlayViewMode.visualNovel ? '继续' : '下一条',
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
                      AppText(line.text, role: AppTextRole.body),
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

class _ChatStage extends StatelessWidget {
  const _ChatStage({
    required this.runtime,
    required this.speakerName,
    required this.onAdvance,
  });

  final MainRuntime runtime;
  final String Function(DialogueLine) speakerName;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final lines = runtime.revealedLines;
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: lines.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTheme.spaceSm),
            itemBuilder: (context, index) {
              final line = lines[index];
              return AppSurface(
                padding: const EdgeInsets.all(AppTheme.spaceSm + 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      speakerName(line),
                      role: AppTextRole.caption,
                      maxLines: 1,
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    AppText(line.text, role: AppTextRole.body),
                  ],
                ),
              );
            },
          ),
        ),
        if (runtime.canAdvance)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceSm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: '显示下一条',
                onPressed: onAdvance,
                variant: AppButtonVariant.ghost,
              ),
            ),
          ),
      ],
    );
  }
}
