import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/visual_stage_page.dart';
import 'package:anoworld/domain/cast_extract/cast_extraction_action.dart';
import 'package:anoworld/domain/cast_extract/cast_merge.dart';
import 'package:anoworld/domain/cast_extract/cast_scan.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:flutter/material.dart';

/// One-click extraction of characters scattered across the world book.
class CastExtractPage extends StatefulWidget {
  const CastExtractPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<CastExtractPage> createState() => _CastExtractPageState();
}

class _CastExtractPageState extends State<CastExtractPage> {
  Project? _project;
  Object? _error;
  bool _busy = true;
  int _progressDone = 0;
  int _progressTotal = 0;
  int _discarded = 0;
  List<CastMergeCandidate> _candidates = const <CastMergeCandidate>[];
  final Set<int> _selected = <int>{};
  int? _appliedCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_busy && _project == null && _error == null && _candidates.isEmpty) {
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
      _appliedCount = null;
      _discarded = 0;
      _progressDone = 0;
      _progressTotal = 0;
      _candidates = const <CastMergeCandidate>[];
      _selected.clear();
    });
    try {
      final projects = AppScope.projectsOf(context);
      final project = await projects.open(widget.projectId);
      if (!mounted) return;
      _project = project;

      final settings = AppScope.settingsOf(context);
      final scan = const CastScanner().scan(project.worldBook);
      if (scan.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final persona = settings.activePersona?.name.trim();
      final action = CastExtractionAction(
        textClient: AppScope.textClientOf(context),
      );
      final result = await action.extract(
        ctx: settings.textPromptContext(),
        scan: scan,
        playerName: persona == null || persona.isEmpty ? '玩家' : persona,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
          });
        },
      );
      if (!mounted) return;
      final candidates = buildCastMergeCandidates(
        extracted: result.characters,
        existing: project.cast,
        newId: () => newEntityId('c'),
      );
      setState(() {
        _busy = false;
        _discarded = result.discarded;
        _candidates = candidates;
        for (var i = 0; i < candidates.length; i++) {
          if (candidates[i].isNew) _selected.add(i);
        }
      });
    } catch (error, stack) {
      AppLog.instance.error(
        '角色抽取失败',
        tag: 'cast.extract',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _apply() async {
    final project = _project;
    if (project == null || _selected.isEmpty) return;
    final chosen = <CastMergeCandidate>[
      for (var i = 0; i < _candidates.length; i++)
        if (_selected.contains(i)) _candidates[i],
    ];
    try {
      final cast = List<CastMember>.of(project.cast);
      for (final candidate in chosen) {
        final at = cast.indexWhere((m) => m.id == candidate.member.id);
        if (at < 0) {
          cast.add(candidate.member);
        } else {
          cast[at] = candidate.member;
        }
      }
      await saveProjectMerged(
        AppScope.projectsOf(context),
        widget.projectId,
        (latest) => latest.copyWith(cast: List<CastMember>.unmodifiable(cast)),
      );
      if (!mounted) return;
      setState(() => _appliedCount = chosen.length);
      AppLog.instance.info(
        '写入 ${chosen.length} 名角色',
        tag: 'cast.extract',
      );
      showAppToast(context, context.strings.castExtractDone(chosen.length));
    } catch (error, stack) {
      AppLog.instance.error(
        '写角色失败',
        tag: 'cast.extract',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      showAppToast(context, context.strings.castExtractFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppPage(
      title: strings.castExtractTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final strings = context.strings;
    if (_busy) {
      final progress = _progressTotal == 0
          ? strings.castExtractRunning
          : '${strings.castExtractRunning} $_progressDone/$_progressTotal';
      return AppPageBody.list(
        children: [
          AppPageGutter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBusyIndicator(),
                const SizedBox(height: AppTheme.spaceSm),
                AppText(progress, role: AppTextRole.caption),
              ],
            ),
          ),
        ],
      );
    }
    if (_error != null) {
      return AppPageBody.list(
        children: [
          AppPageGutter(
            child: AppEmptyState(
              message: strings.castExtractFailed,
              action: AppButton(
                label: strings.retry,
                variant: AppButtonVariant.secondary,
                onPressed: _run,
              ),
            ),
          ),
        ],
      );
    }
    if (_appliedCount != null) {
      return AppPageBody.list(
        children: [
          AppPageGutter(
            child: AppEmptyState(
              message: strings.castExtractDone(_appliedCount!),
              detail: strings.castExtractIntro,
              action: AppButton(
                label: strings.castExtractGoVisual,
                onPressed: () => pushAppSlide(
                  context,
                  VisualStagePage(projectId: widget.projectId),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_candidates.isEmpty) {
      return AppPageBody.list(
        children: [
          AppPageGutter(
            child: AppEmptyState(
              message: strings.castExtractEmpty,
              detail: strings.castExtractEmptyDetail,
              action: AppButton(
                label: strings.retry,
                variant: AppButtonVariant.secondary,
                onPressed: _run,
              ),
            ),
          ),
        ],
      );
    }

    final groups = <String, List<int>>{};
    for (var i = 0; i < _candidates.length; i++) {
      final title = _candidates[i].extracted.sourceEntry.trim();
      groups.putIfAbsent(title.isEmpty ? strings.unnamed : title, () => []).add(i);
    }
    return AppPageBody.list(
      children: [
        AppPageGutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(strings.castExtractIntro, role: AppTextRole.caption),
              if (_discarded > 0) ...[
                const SizedBox(height: AppTheme.spaceXs),
                AppText(
                  strings.castExtractDiscarded(_discarded),
                  role: AppTextRole.caption,
                ),
              ],
            ],
          ),
        ),
        for (final entry in groups.entries) ...[
          AppPageGutter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceMd),
              child: AppText(
                entry.key,
                role: AppTextRole.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (var j = 0; j < entry.value.length; j++) ...[
            _CandidateRow(
              candidate: _candidates[entry.value[j]],
              selected: _selected.contains(entry.value[j]),
              onChanged: (on) {
                setState(() {
                  if (on) {
                    _selected.add(entry.value[j]);
                  } else {
                    _selected.remove(entry.value[j]);
                  }
                });
              },
            ),
            if (j < entry.value.length - 1) const AppListHairline(),
          ],
        ],
        AppPageGutter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            child: AppButton(
              label: strings.castExtractApply,
              expanded: true,
              onPressed: _selected.isEmpty ? null : _apply,
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.onChanged,
  });

  final CastMergeCandidate candidate;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final member = candidate.member;
    final details = <String>[
      if (member.summary.trim().isNotEmpty) member.summary.trim(),
      if (member.personality.trim().isNotEmpty)
        '${strings.castPersonalityLabel}：${member.personality.trim()}',
      if (member.speechStyle.trim().isNotEmpty)
        '${strings.castSpeechLabel}：${member.speechStyle.trim()}',
      if (member.aliases.isNotEmpty)
        '${strings.castAliasesLabel}：${member.aliases.join('、')}',
    ];
    return AppPageGutter(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceXs),
            child: AppSwitch(value: selected, onChanged: onChanged),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(member.name, role: AppTextRole.subtitle),
                  const SizedBox(height: AppTheme.spaceXs),
                  AppText(
                    candidate.isNew
                        ? strings.castExtractNew
                        : strings.castExtractExisting,
                    role: AppTextRole.caption,
                    fontWeight: FontWeight.w600,
                  ),
                  for (final line in details) ...[
                    const SizedBox(height: AppTheme.spaceXs),
                    AppText(
                      line,
                      role: AppTextRole.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
