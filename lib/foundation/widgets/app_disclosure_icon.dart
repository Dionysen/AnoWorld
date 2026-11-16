import 'package:flutter/material.dart';

/// Expand/collapse chevron for disclosure rows.
class AppDisclosureIcon extends StatelessWidget {
  const AppDisclosureIcon({super.key, required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(
      expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      size: 20,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}
