import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_segmented.dart';

/// Text-only tab strip with a colored underline under the active tab.
///
/// Sits directly under the page title as a lighter alternative to
/// [AppSegmented]: labels align left, the strip closes with a hairline.
class AppUnderlineTabs<T> extends StatelessWidget {
  const AppUnderlineTabs({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Key of the underline bar under [label] (for tests / a11y checks).
  static Key indicatorKey(String label) => ValueKey('underline_tab_$label');

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              _UnderlineTab(
                label: option.label,
                selected: option.value == value,
                onTap: () => onChanged(option.value),
              ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: AppTheme.listHairline(context)),
      ],
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = AppUiTokens.of(context).radius.clamp(1.0, 2.0);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceInline,
          ),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                AnimatedContainer(
                  key: AppUnderlineTabs.indicatorKey(label),
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
