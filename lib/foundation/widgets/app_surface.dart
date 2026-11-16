import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

/// Raised panel using theme surface tokens.
///
/// Set [elevated] for a floating card with shadow (e.g. small-screen station card).
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spaceMd),
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    final shape = tokens.shape(
      side: elevated
          ? BorderSide.none
          : BorderSide(color: theme.colorScheme.outline),
    );
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
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
