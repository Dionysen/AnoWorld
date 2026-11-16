import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icon-only control for title-band actions and compact chrome.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      color: theme.colorScheme.onSurface,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(AppTheme.spaceXs),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
    return button;
  }
}
