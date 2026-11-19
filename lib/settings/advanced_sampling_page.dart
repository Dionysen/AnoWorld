import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/widgets/app_nested_settings_group.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:flutter/material.dart';

/// Full-page advanced sampler fields (opened from 预设 → 高级采样).
class AdvancedSamplingPage extends StatelessWidget {
  const AdvancedSamplingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: context.strings.advancedSamplingTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: const AppPageBody.list(children: [_AdvancedSamplingBody()]),
    );
  }
}

class _AdvancedSamplingBody extends StatelessWidget {
  const _AdvancedSamplingBody();

  Future<void> _patch(
    BuildContext context,
    GenerationPreset Function(GenerationPreset) fn,
  ) async {
    final controller = AppScope.settingsOf(context);
    await controller.updateGeneration(fn(controller.ai.generation));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final strings = context.strings;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final gen = controller.ai.generation;
        return AppSettingsNestedColumn(
          children: [
            AppSlider(
              label: 'Top K',
              icon: Icons.filter_list_outlined,
              value: gen.topK.toDouble(),
              min: 0,
              max: 200,
              step: 1,
              valueText: (v) => v.round().toString(),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(topK: v.round())),
            ),
            AppSlider(
              label: 'Min P',
              icon: Icons.horizontal_rule,
              value: gen.minP,
              min: 0,
              max: 1,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(minP: v)),
            ),
            AppSlider(
              label: 'Typical P',
              icon: Icons.ssid_chart_outlined,
              value: gen.typicalP,
              min: 0,
              max: 1,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(typicalP: v)),
            ),
            AppSlider(
              label: 'Top A',
              icon: Icons.stacked_line_chart,
              value: gen.topA,
              min: 0,
              max: 1,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(topA: v)),
            ),
            AppSlider(
              label: 'Tail Free',
              icon: Icons.timeline_outlined,
              value: gen.tailFreeSampling,
              min: 0,
              max: 1,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(tailFreeSampling: v)),
            ),
            AppSlider(
              label: strings.repetitionPenalty,
              icon: Icons.repeat_outlined,
              value: gen.repetitionPenalty,
              min: 1,
              max: 2,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(repetitionPenalty: v)),
            ),
            AppSlider(
              label: strings.penaltyRange,
              icon: Icons.straighten_outlined,
              value: gen.repetitionPenaltyRange.toDouble(),
              min: 0,
              max: 2048,
              step: 64,
              valueText: (v) => v.round().toString(),
              onChanged: (v) => _patch(
                context,
                (prev) => prev.copyWith(repetitionPenaltyRange: v.round()),
              ),
            ),
            AppSlider(
              label: strings.frequencyPenalty,
              icon: Icons.speed_outlined,
              value: gen.frequencyPenalty,
              min: -2,
              max: 2,
              step: 0.1,
              valueText: (v) => v.toStringAsFixed(1),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(frequencyPenalty: v)),
            ),
            AppSlider(
              label: strings.presencePenalty,
              icon: Icons.place_outlined,
              value: gen.presencePenalty,
              min: -2,
              max: 2,
              step: 0.1,
              valueText: (v) => v.toStringAsFixed(1),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(presencePenalty: v)),
            ),
            AppSlider(
              label: strings.mirostatMode,
              icon: Icons.tune_outlined,
              value: gen.mirostatMode.toDouble(),
              min: 0,
              max: 2,
              step: 1,
              valueText: (v) => v.round().toString(),
              onChanged: (v) => _patch(
                context,
                (prev) => prev.copyWith(mirostatMode: v.round()),
              ),
            ),
            AppSlider(
              label: 'Mirostat Tau',
              icon: Icons.waves_outlined,
              value: gen.mirostatTau,
              min: 0,
              max: 10,
              step: 0.5,
              valueText: (v) => v.toStringAsFixed(1),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(mirostatTau: v)),
            ),
            AppSlider(
              label: 'Mirostat Eta',
              icon: Icons.gradient_outlined,
              value: gen.mirostatEta,
              min: 0,
              max: 1,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(mirostatEta: v)),
            ),
            AppTextEditTile(
              title: strings.randomSeed,
              subtitle: strings.randomSeedHint,
              icon: Icons.casino_outlined,
              value: '${gen.seed}',
              keyboardType: TextInputType.number,
              onSubmitted: (raw) {
                final v = int.tryParse(raw.trim());
                if (v == null) return;
                _patch(context, (prev) => prev.copyWith(seed: v));
              },
            ),
            AppTextEditTile(
              title: strings.stopSequences,
              subtitle: strings.stopSequencesHint,
              icon: Icons.stop_circle_outlined,
              value: gen.stopSequences.join('\n'),
              emptyLabel: strings.notSet,
              minLines: 2,
              maxLines: 6,
              showDivider: false,
              onSubmitted: (raw) {
                final lines = raw
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList(growable: false);
                _patch(context, (prev) => prev.copyWith(stopSequences: lines));
              },
            ),
          ],
        );
      },
    );
  }
}
