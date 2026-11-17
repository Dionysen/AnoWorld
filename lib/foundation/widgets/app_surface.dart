import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_nested_settings_style.dart';

/// Raised panel using theme surface tokens.
///
/// Set [elevated] for a floating card with shadow (e.g. small-screen station card).
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spaceMd),
    this.elevated = false,
    this.nested = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  /// Secondary tier under a settings expand block (lighter contrast, no shadow).
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    final scheme = theme.colorScheme;
    final shape = nested
        ? AppNestedSettingsStyle.itemShape(context)
        : tokens.shape(
            side: elevated ? BorderSide.none : BorderSide(color: scheme.outline),
          );
    return Material(
      color: nested
          ? AppNestedSettingsStyle.fill(scheme)
          : scheme.surfaceContainerHighest,
      elevation: elevated ? AppTheme.surfaceElevation : 0,
      shadowColor: theme.colorScheme.shadow.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.72 : 0.36,
      ),
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}
