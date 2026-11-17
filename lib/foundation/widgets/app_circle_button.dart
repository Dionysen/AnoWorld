import 'package:flutter/material.dart';

enum AppCircleButtonVariant { filled, tonal, ghost }

/// Icon-only circular control. Shape is always a circle — never reads the
/// corner-radius slider / [AppUiTokens.radius].
///
/// Default [AppCircleButtonVariant.ghost]: no resting fill; press / hover still
/// show the ink overlay. Prefer this for chrome (back, title actions, overlays).
/// [AppCircleButtonVariant.filled] is for primary circular CTAs (FAB).
/// [AppCircleButtonVariant.tonal] keeps a resting fill when a soft chip is needed.
class AppCircleButton extends StatelessWidget {
  const AppCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = diameter,
    this.iconSize = 22,
    this.variant = AppCircleButtonVariant.ghost,
  });

  /// Default hit target — top chrome [AppPage.actions], tool rows, etc.
  static const double diameter = 40;

  /// Bottom-right floating circle (Scaffold FAB, graph corner chrome).
  static const double fabDiameter = 54;

  /// Icon size paired with [fabDiameter].
  static const double fabIconSize = 30;

  const AppCircleButton.fab({
    Key? key,
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
    AppCircleButtonVariant variant = AppCircleButtonVariant.filled,
  }) : this(
          key: key,
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          variant: variant,
          size: fabDiameter,
          iconSize: fabIconSize,
        );

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final AppCircleButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg, Color disabledBg) = switch (variant) {
      AppCircleButtonVariant.filled => (
          scheme.primary,
          scheme.onPrimary,
          scheme.primary.withValues(alpha: 0.4),
        ),
      AppCircleButtonVariant.tonal => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
      AppCircleButtonVariant.ghost => (
          Colors.transparent,
          scheme.onSurface,
          Colors.transparent,
        ),
    };

    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: iconSize),
      color: fg,
      style: IconButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: disabledBg,
        disabledForegroundColor: fg.withValues(alpha: 0.38),
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        minimumSize: Size.square(size),
        fixedSize: Size.square(size),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
    );

    if (size == diameter) return button;
    return SizedBox(width: size, height: size, child: button);
  }
}
