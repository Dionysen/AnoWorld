import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// Encapsulated button. Business code must not use ElevatedButton/TextButton.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool expanded;

  static const Size _minSize = Size(0, AppTheme.buttonHeight);
  static const Size _fixedSize = Size.fromHeight(AppTheme.buttonHeight);
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: AppTheme.spaceMd,
    vertical: AppTheme.spaceSm,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    final shape = tokens.shape();
    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: _minSize,
            fixedSize: _fixedSize,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            padding: _padding,
            shape: shape,
          ),
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            side: BorderSide(color: theme.colorScheme.outline),
            minimumSize: _minSize,
            fixedSize: _fixedSize,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            padding: _padding,
            shape: shape,
          ),
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            minimumSize: _minSize,
            fixedSize: _fixedSize,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            padding: _padding,
            shape: shape,
          ),
          child: child,
        ),
    };
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
