import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
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

/// Dual-mode runtime sharing one [MainRuntime] pointer.
class PlaySessionPage extends StatefulWidget {
  const PlaySessionPage({
    super.key,
    required this.project,
    this.resumeSave = true,
    this.initialSave,
  });

  final Project project;

  /// When true, load the auto-save slot if present.
  final bool resumeSave;
  final MainSavePointer? initialSave;

  @override
  State<PlaySessionPage> createState() => _PlaySessionPageState();
}

class _PlaySessionPageState extends State<PlaySessionPage> {
  late MainRuntime _runtime;
  PlayViewMode _mode = PlayViewMode.visualNovel;
  String? _status;
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _runtime = MainRuntime(widget.project.main, save: widget.initialSave);
    if (widget.resumeSave && widget.initialSave == null) {
      _maybeLoadAutoSave();
    }
  }

  Future<void> _maybeLoadAutoSave() async {
    final slot =
        await AppScope.savesOf(context).load(widget.project.meta.id);
    if (!mounted || slot == null) return;
    setState(() {
      _runtime.restore(slot.pointer);
      _status = '已读取进度';
    });
  }

  String _speakerName(DialogueLine line) {
    if (line.kind == DialogueKind.narration || line.speakerId == null) {
      return '旁白';
    }
    final member = widget.project.castById(line.speakerId!);
    return member?.name ?? line.speakerId!;
  }

  String _castName(String characterId) {
    return widget.project.castById(characterId)?.name ?? characterId;
  }

  Future<void> _save() async {
    final saves = AppScope.savesOf(context);
    await saves.save(
      projectId: widget.project.meta.id,
      pointer: _runtime.toSave(),
    );
    if (!mounted) return;
    setState(() => _status = '进度已保存');
  }

  void _advance() {
    if (!_runtime.canAdvance) return;
    setState(_runtime.advance);
  }

  void _choose(Choice choice) {
    setState(() => _runtime.choose(choice.id));
  }

  void _restart() {
    setState(() {
      _runtime = MainRuntime(widget.project.main);
      _status = '已从头开始';
    });
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
                ] else
                  AppButton(
                    label: _mode == PlayViewMode.visualNovel ? '继续' : '下一条',
                    onPressed: _runtime.canAdvance ? _advance : null,
                    expanded: true,
                  ),
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
  });

  final MainRuntime runtime;
  final String Function(DialogueLine) speakerName;
  final String Function(String) castName;
  final VoidCallback onAdvance;
  final bool narrow;

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
                  location?.isNotEmpty == true ? location! : '场景',
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
