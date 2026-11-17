import 'dart:math' as math;

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_nested_settings_group.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_settings_expand_tile.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_surface.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Live [GenerationPreset] editor (ST / NativeTavern sampler fields).
class AiGenerationSettingsPanel extends StatefulWidget {
  const AiGenerationSettingsPanel({super.key});

  @override
  State<AiGenerationSettingsPanel> createState() =>
      _AiGenerationSettingsPanelState();
}

class _AiGenerationSettingsPanelState extends State<AiGenerationSettingsPanel> {
  var _advancedOpen = false;

  Future<void> _patch(GenerationPreset Function(GenerationPreset) fn) async {
    final controller = AppScope.settingsOf(context);
    await controller.updateGeneration(fn(controller.ai.generation));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final g = controller.ai.generation;
        return AppSettingsNestedColumn(
          children: [
            AppSlider(
              nested: true,
              label: '单次最长输出',
              icon: Icons.output_outlined,
              value: g.maxTokens.toDouble().clamp(256, 8192),
              min: 256,
              max: 8192,
              step: 256,
              valueText: (v) => '${v.round()} token',
              onChanged: (v) =>
                  _patch((prev) => prev.copyWith(maxTokens: v.round())),
            ),
            AppSlider(
              nested: true,
              label: '上下文长度',
              icon: Icons.memory_outlined,
              value: _contextSlider(g.contextLength),
              min: 0,
              max: 1,
              step: 0.02,
              valueText: (_) => _formatContext(g.contextLength),
              onChanged: (v) => _patch(
                (prev) => prev.copyWith(contextLength: _contextFromSlider(v)),
              ),
            ),
            AppSlider(
              nested: true,
              label: '温度',
              icon: Icons.thermostat_outlined,
              value: g.temperature,
              min: 0,
              max: 2,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) => _patch((prev) => prev.copyWith(temperature: v)),
            ),
            AppSlider(
              nested: true,
              label: 'Top P',
              icon: Icons.pie_chart_outline,
              value: g.topP,
              min: 0,
              max: 1,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) => _patch((prev) => prev.copyWith(topP: v)),
            ),
            AppListTile(
              nested: true,
              title: '流式输出',
              subtitle: '边生成边返回',
              icon: Icons.stream_outlined,
              trailing: AppSwitch(
                value: g.streamEnabled,
                onChanged: (on) =>
                    _patch((prev) => prev.copyWith(streamEnabled: on)),
              ),
              onTap: () => _patch(
                (prev) => prev.copyWith(streamEnabled: !prev.streamEnabled),
              ),
            ),
            AppSettingsExpandTile(
              nested: true,
              title: '高级采样',
              subtitle: 'Top K、惩罚、Mirostat 等',
              icon: Icons.science_outlined,
              expanded: _advancedOpen,
              onToggle: () => setState(() => _advancedOpen = !_advancedOpen),
              child: _AdvancedSampling(gen: g, onPatch: _patch),
            ),
          ],
        );
      },
    );
  }

  static const _contextMin = 4096.0;
  static const _contextMax = 200000.0;

  static double _contextSlider(int contextLength) {
    final clamped =
        contextLength.clamp(_contextMin.toInt(), _contextMax.toInt()).toDouble();
    return (math.log(clamped) - math.log(_contextMin)) /
        (math.log(_contextMax) - math.log(_contextMin));
  }

  static int _contextFromSlider(double t) {
    final v = _contextMin * math.pow(_contextMax / _contextMin, t.clamp(0, 1));
    return v.round();
  }

  static String _formatContext(int tokens) {
    if (tokens >= 1000) {
      final k = tokens / 1000;
      return '${k.toStringAsFixed(k >= 10 || tokens % 1000 == 0 ? 0 : 1)}k';
    }
    return '$tokens';
  }
}

class _AdvancedSampling extends StatefulWidget {
  const _AdvancedSampling({
    required this.gen,
    required this.onPatch,
  });

  final GenerationPreset gen;
  final Future<void> Function(GenerationPreset Function(GenerationPreset)) onPatch;

  @override
  State<_AdvancedSampling> createState() => _AdvancedSamplingState();
}

class _AdvancedSamplingState extends State<_AdvancedSampling> {
  late final TextEditingController _seed;
  late final TextEditingController _stops;

  @override
  void initState() {
    super.initState();
    _seed = TextEditingController(text: '${widget.gen.seed}');
    _stops = TextEditingController(text: widget.gen.stopSequences.join('\n'));
  }

  @override
  void didUpdateWidget(covariant _AdvancedSampling oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gen.seed != widget.gen.seed) {
      _seed.text = '${widget.gen.seed}';
    }
    final nextStops = widget.gen.stopSequences.join('\n');
    if (oldWidget.gen.stopSequences != widget.gen.stopSequences) {
      _stops.text = nextStops;
    }
  }

  @override
  void dispose() {
    _seed.dispose();
    _stops.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gen = widget.gen;
    final patch = widget.onPatch;
    return AppSettingsNestedColumn(
      children: [
        AppSlider(
          nested: true,
          label: 'Top K',
          value: gen.topK.toDouble(),
          min: 0,
          max: 200,
          step: 1,
          valueText: (v) => v.round().toString(),
          onChanged: (v) => patch((prev) => prev.copyWith(topK: v.round())),
        ),
        AppSlider(
          nested: true,
          label: 'Min P',
          value: gen.minP,
          min: 0,
          max: 1,
          step: 0.05,
          valueText: (v) => v.toStringAsFixed(2),
          onChanged: (v) => patch((prev) => prev.copyWith(minP: v)),
        ),
        AppSlider(
          nested: true,
          label: 'Typical P',
          value: gen.typicalP,
          min: 0,
          max: 1,
          step: 0.05,
          valueText: (v) => v.toStringAsFixed(2),
          onChanged: (v) => patch((prev) => prev.copyWith(typicalP: v)),
        ),
        AppSlider(
          nested: true,
          label: 'Top A',
          value: gen.topA,
          min: 0,
          max: 1,
          step: 0.05,
          valueText: (v) => v.toStringAsFixed(2),
          onChanged: (v) => patch((prev) => prev.copyWith(topA: v)),
        ),
        AppSlider(
          nested: true,
          label: 'Tail Free',
          value: gen.tailFreeSampling,
          min: 0,
          max: 1,
          step: 0.05,
          valueText: (v) => v.toStringAsFixed(2),
          onChanged: (v) =>
              patch((prev) => prev.copyWith(tailFreeSampling: v)),
        ),
        AppSlider(
          nested: true,
          label: '重复惩罚',
          value: gen.repetitionPenalty,
          min: 1,
          max: 2,
          step: 0.05,
          valueText: (v) => v.toStringAsFixed(2),
          onChanged: (v) =>
              patch((prev) => prev.copyWith(repetitionPenalty: v)),
        ),
        AppSlider(
          nested: true,
          label: '惩罚范围',
          value: gen.repetitionPenaltyRange.toDouble(),
          min: 0,
          max: 2048,
          step: 64,
          valueText: (v) => v.round().toString(),
          onChanged: (v) => patch(
            (prev) => prev.copyWith(repetitionPenaltyRange: v.round()),
          ),
        ),
        AppSlider(
          nested: true,
          label: '频率惩罚',
          value: gen.frequencyPenalty,
          min: -2,
          max: 2,
          step: 0.1,
          valueText: (v) => v.toStringAsFixed(1),
          onChanged: (v) =>
              patch((prev) => prev.copyWith(frequencyPenalty: v)),
        ),
        AppSlider(
          nested: true,
          label: '存在惩罚',
          value: gen.presencePenalty,
          min: -2,
          max: 2,
          step: 0.1,
          valueText: (v) => v.toStringAsFixed(1),
          onChanged: (v) =>
              patch((prev) => prev.copyWith(presencePenalty: v)),
        ),
        AppSlider(
          nested: true,
          label: 'Mirostat 模式',
          value: gen.mirostatMode.toDouble(),
          min: 0,
          max: 2,
          step: 1,
          valueText: (v) => v.round().toString(),
          onChanged: (v) =>
              patch((prev) => prev.copyWith(mirostatMode: v.round())),
        ),
        AppSlider(
          nested: true,
          label: 'Mirostat Tau',
          value: gen.mirostatTau,
          min: 0,
          max: 10,
          step: 0.5,
          valueText: (v) => v.toStringAsFixed(1),
          onChanged: (v) => patch((prev) => prev.copyWith(mirostatTau: v)),
        ),
        AppSlider(
          nested: true,
          label: 'Mirostat Eta',
          value: gen.mirostatEta,
          min: 0,
          max: 1,
          step: 0.05,
          valueText: (v) => v.toStringAsFixed(2),
          onChanged: (v) => patch((prev) => prev.copyWith(mirostatEta: v)),
        ),
        AppPageGutter(
          child: AppSurface(
            nested: true,
            child: AppTextField(
              label: '随机种子',
              hint: '-1 表示每次随机',
              keyboardType: TextInputType.number,
              controller: _seed,
              onEditingComplete: () {
                final v = int.tryParse(_seed.text.trim());
                if (v != null) {
                  patch((prev) => prev.copyWith(seed: v));
                }
              },
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceGroup),
        AppPageGutter(
          child: AppSurface(
            nested: true,
            child: AppTextField(
              label: '停止序列',
              hint: '每行一条',
              minLines: 2,
              maxLines: 6,
              controller: _stops,
              onEditingComplete: () {
                final lines = _stops.text
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList(growable: false);
                patch((prev) => prev.copyWith(stopSequences: lines));
              },
            ),
          ),
        ),
      ],
    );
  }
}