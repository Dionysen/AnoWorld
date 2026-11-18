import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
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
      title: '高级采样',
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
              label: '重复惩罚',
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
              label: '惩罚范围',
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
              label: '频率惩罚',
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
              label: '存在惩罚',
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
              label: 'Mirostat 模式',
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
              title: '随机种子',
              subtitle: '-1 表示每次随机',
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
              title: '停止序列',
              subtitle: '每行一条',
              icon: Icons.stop_circle_outlined,
              value: gen.stopSequences.join('\n'),
              emptyLabel: '未设置',
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
