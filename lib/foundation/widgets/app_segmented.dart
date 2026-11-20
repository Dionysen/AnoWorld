import 'package:flutter/material.dart';

import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

class AppSegmentOption<T> {
  const AppSegmentOption({required this.value, required this.label, this.icon});

  final T value;

  /// Visible text, or the tooltip / screen-reader name in icon-only groups.
  final String label;
  final IconData? icon;
}

/// Compact two/three-way mode switch.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.of(context);
    return _GroupShell(
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment(
                label: option.label,
                icon: option.icon,
                selected: option.value == value,
                radius: tokens.radius,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon-only mode switch: one square per option; [AppSegmentOption.label] is
/// its tooltip. For rows with no space for text (chat composer).
class AppIconSegmented<T> extends StatelessWidget {
  AppIconSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  }) : assert(
         options.every((option) => option.icon != null),
         'AppIconSegmented draws icons only; give every option an icon',
       );

  /// Square, sized to the chat send button.
  static const double segmentSize = 34;

  final List<AppSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.of(context);
    return _GroupShell(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _IconSegment(
              icon: option.icon!,
              name: option.label,
              selected: option.value == value,
              radius: tokens.radius,
              onTap: () => onChanged(option.value),
            ),
        ],
      ),
    );
  }
}

/// Filled capsule the segments sit in; shared by both variants.
class _GroupShell extends StatelessWidget {
  const _GroupShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: tokens.shape(side: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: child,
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.radius,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppShapes.continuous(radius: (radius - 1).clamp(0.0, radius));
    final color = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spaceSm,
            horizontal: AppTheme.spaceXs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppTheme.spaceXs),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconSegment extends StatelessWidget {
  const _IconSegment({
    required this.icon,
    required this.name,
    required this.selected,
    required this.radius,
    required this.onTap,
  });

  final IconData icon;

  /// Tooltip and screen-reader name, since nothing is drawn.
  final String name;
  final bool selected;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppShapes.continuous(radius: (radius - 1).clamp(0.0, radius));
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: name,
        child: Material(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: SizedBox(
              width: AppIconSegmented.segmentSize,
              height: AppIconSegmented.segmentSize,
              child: Center(
                child: Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labeled control block: caption + segmented options (settings forms).
class AppOptionGroup<T> extends StatelessWidget {
  const AppOptionGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<AppSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppTheme.spaceSm),
        AppSegmented<T>(options: options, value: value, onChanged: onChanged),
      ],
    );
  }
}
