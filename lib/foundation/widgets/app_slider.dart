import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_text.dart';

/// Labeled stepped slider. Business code must not use [Slider] directly.
///
/// [step] snaps the value; divisions are derived as `(max - min) / step`.
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.valueText,
  }) : assert(step > 0),
       assert(max >= min);

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  /// Optional override for the trailing readout; defaults to a compact number.
  final String Function(double value)? valueText;

  static double snap({
    required double value,
    required double min,
    required double max,
    required double step,
  }) {
    if (max <= min) return min;
    final clamped = value.clamp(min, max);
    final steps = ((clamped - min) / step).round();
    final snapped = min + steps * step;
    return double.parse(snapped.clamp(min, max).toStringAsFixed(6));
  }

  int get _divisions {
    final count = ((max - min) / step).round();
    return count < 1 ? 1 : count;
  }

  String _defaultValueText(double v) {
    if (step >= 1) return v.round().toString();
    final places = step >= 0.1 ? 1 : 2;
    return v.toStringAsFixed(places);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = snap(value: value, min: min, max: max, step: step);
    final readout = valueText?.call(display) ?? _defaultValueText(display);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(label, role: AppTextRole.caption),
            ),
            AppText(readout, role: AppTextRole.caption),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXs),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.outline,
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            valueIndicatorColor: theme.colorScheme.primary,
          ),
          child: Slider(
            value: display,
            min: min,
            max: max,
            divisions: _divisions,
            label: readout,
            onChanged: (next) {
              onChanged(snap(value: next, min: min, max: max, step: step));
            },
          ),
        ),
      ],
    );
  }
}
