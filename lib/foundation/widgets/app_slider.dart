import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_list_tile.dart';
import 'app_sheet.dart';
import 'app_text.dart';

/// Settings-style value row that opens a compact sheet with a stepped slider.
///
/// Business code must not use [Slider] directly. [step] snaps on change; the
/// track stays continuous (no tick marks). Row chrome matches [AppListTile].
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.valueText,
    this.nested = false,
    this.showDivider = true,
  }) : assert(step > 0),
       assert(max >= min);

  final String label;

  /// Short row / sheet caption (no trailing period).
  final String? subtitle;
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

  String _defaultValueText(double v) {
    if (step >= 1) return v.round().toString();
    final places = step >= 0.1 ? 1 : 2;
    return v.toStringAsFixed(places);
  }

  String _readout(double v) {
    final display = snap(value: v, min: min, max: max, step: step);
    return valueText?.call(display) ?? _defaultValueText(display);
  }

  Future<void> _openSheet(BuildContext context) async {
    var current = snap(value: value, min: min, max: max, step: step);
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.compact,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final scheme = Theme.of(context).colorScheme;
            final readout = _readout(current);
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                AppTheme.pagePadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppText(label, role: AppTextRole.subtitle, maxLines: 2),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spaceXs),
                    AppText(
                      subtitle!,
                      role: AppTextRole.caption,
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: AppTheme.spaceMd),
                  AppText(
                    readout,
                    role: AppTextRole.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  SliderTheme(
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
                      value: current,
                      min: min,
                      max: max,
                      label: readout,
                      onChanged: (next) {
                        final snapped = snap(
                          value: next,
                          min: min,
                          max: max,
                          step: step,
                        );
                        setLocal(() => current = snapped);
                        onChanged(snapped);
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = snap(value: value, min: min, max: max, step: step);
    final readout = valueText?.call(display) ?? _defaultValueText(display);
    return AppListTile(
      title: label,
      subtitle: subtitle,
      icon: icon,
      nested: nested,
      showDivider: showDivider,
      trailing: AppText(readout, role: AppTextRole.caption),
      onTap: () => _openSheet(context),
    );
  }
}
