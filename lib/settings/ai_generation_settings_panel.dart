import 'dart:math' as math;

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_nested_settings_group.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/settings/advanced_sampling_page.dart';
import 'package:flutter/material.dart';

/// Root-level generation controls (max tokens, context, temperature, …).
/// Advanced sampler opens [AdvancedSamplingPage].
class AiGenerationSettingsPanel extends StatelessWidget {
  const AiGenerationSettingsPanel({super.key});

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
        final g = controller.ai.generation;
        return AppSettingsNestedColumn(
          children: [
            AppSlider(
              label: strings.maxOutputLabel,
              icon: Icons.output_outlined,
              value: g.maxTokens.toDouble().clamp(256, 8192),
              min: 256,
              max: 8192,
              step: 256,
              valueText: (v) => '${v.round()} token',
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(maxTokens: v.round())),
            ),
            AppSlider(
              label: strings.contextLengthLabel,
              icon: Icons.memory_outlined,
              value: _contextSlider(g.contextLength),
              min: 0,
              max: 1,
              step: 0.02,
              valueText: (_) => _formatContext(g.contextLength),
              onChanged: (v) => _patch(
                context,
                (prev) => prev.copyWith(contextLength: _contextFromSlider(v)),
              ),
            ),
            AppSlider(
              label: strings.temperatureLabel,
              icon: Icons.thermostat_outlined,
              value: g.temperature,
              min: 0,
              max: 2,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(temperature: v)),
            ),
            AppSlider(
              label: 'Top P',
              icon: Icons.pie_chart_outline,
              value: g.topP,
              min: 0,
              max: 1,
              step: 0.05,
              valueText: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _patch(context, (prev) => prev.copyWith(topP: v)),
            ),
            AppListTile(
              title: strings.streamOutput,
              subtitle: strings.streamOutputHint,
              icon: Icons.stream_outlined,
              trailing: AppSwitch(
                value: g.streamEnabled,
                onChanged: (on) =>
                    _patch(context, (prev) => prev.copyWith(streamEnabled: on)),
              ),
              onTap: () => _patch(
                context,
                (prev) => prev.copyWith(streamEnabled: !prev.streamEnabled),
              ),
            ),
            AppListTile(
              title: strings.advancedSampling,
              subtitle: strings.advancedSamplingHint,
              icon: Icons.science_outlined,
              trailing: const AppForwardIcon(),
              onTap: () {
                pushAppSlide(context, const AdvancedSamplingPage());
              },
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
