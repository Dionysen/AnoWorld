import 'package:flutter/material.dart';

import 'app_circle_button.dart';

/// Icon-only control for tool rows and compact chrome.
///
/// Always a circle via [AppCircleButton] — never reads the corner-radius
/// slider / [AppUiTokens.radius].
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
  static const double hitTarget = AppCircleButton.diameter;

  /// Default glyph size inside the hit target.
  static const double glyphSize = 22;

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return AppCircleButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      size: size,
      iconSize: iconSize,
      variant: AppCircleButtonVariant.ghost,
    );
  }
}
