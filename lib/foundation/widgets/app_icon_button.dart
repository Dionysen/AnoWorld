import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icon-only control for title-band actions and compact chrome.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = hitTarget,
    this.iconSize = glyphSize,
  });

  /// Default hit target (matches [AppCircleButton.diameter]).
  static const double hitTarget = 40;

  /// Default glyph size inside the hit target.
  static const double glyphSize = 22;

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: iconSize),
        color: theme.colorScheme.onSurface,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.standard,
        constraints: BoxConstraints.tightFor(width: size, height: size),
      ),
    );
  }
}
