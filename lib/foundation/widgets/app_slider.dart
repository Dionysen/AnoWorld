import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_list_hairline.dart';
import 'app_list_tile.dart';
import 'app_text.dart';

/// Labeled stepped slider. Business code must not use [Slider] directly.
///
/// [step] snaps the value; divisions are derived as `(max - min) / step`.
/// Full-width flat row (same language as [AppListTile]), not an island card.
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.icon,
    this.valueText,
    this.nested = false,
    this.showDivider = true,
  }) : assert(step > 0),
       assert(max >= min);

  final String label;
  final IconData? icon;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  /// Optional override for the trailing readout; defaults to a compact number.
  final String Function(double value)? valueText;

  /// Secondary tier inside an expanded settings block.
  final bool nested;

  final bool showDivider;

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
    final scheme = theme.colorScheme;
    final display = snap(value: value, min: min, max: max, step: step);
    final readout = valueText?.call(display) ?? _defaultValueText(display);
    final left = AppTheme.spaceMd + (nested ? AppTheme.spaceMd : 0);

    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        left,
        AppTheme.spaceInline,
        AppTheme.spaceMd,
        AppTheme.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppListTile.iconSize,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.spaceInline),
              ],
              Expanded(
                child: AppText(
                  label,
                  role: AppTextRole.subtitle,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              AppText(readout, role: AppTextRole.caption),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          // Same inset both sides; with icon, align under the title text.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: icon != null
                  ? AppListTile.iconSize + AppTheme.spaceInline
                  : AppTheme.spaceInline,
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: scheme.primary,
                inactiveTrackColor: scheme.outline,
                thumbColor: scheme.primary,
                overlayColor: scheme.primary.withValues(alpha: 0.12),
                valueIndicatorColor: scheme.primary,
                padding: EdgeInsets.zero,
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
          ),
        ],
      ),
    );

    if (!showDivider) return body;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const AppListHairline(),
      ],
    );
  }
}
