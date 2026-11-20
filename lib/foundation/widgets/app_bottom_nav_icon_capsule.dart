import 'dart:ui' show ImageFilter;

import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/theme/app_shapes.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_press_scale.dart';
import 'package:flutter/material.dart';

/// Icon-only glass capsule matching [AppNavShell] bottom bar chrome.
class AppBottomNavIconCapsule extends StatelessWidget {
  const AppBottomNavIconCapsule({
    super.key,
    required this.icon,
    required this.onPressed,
    this.selectedIcon,
    this.selected = false,
    this.tooltip,
    this.enabled = true,
    this.busy = false,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final bool selected;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool enabled;

  /// Replaces the icon with a rotating progress ring (work in flight).
  final bool busy;

  static const double side = AppLayout.bottomNavHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = side / 2;
    final capsule = AppShapes.continuous(
      radius: radius,
      side: BorderSide(
        color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.45 : 0.35),
      ),
    );
    final glassFill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.32 : 0.48,
    );
    final active = enabled && onPressed != null;
    final color = !active
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    final pill = AppShapes.continuous(radius: radius);

    final button = AppPressScale(
      enabled: active,
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        shape: pill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: active ? onPressed : null,
          customBorder: pill,
          child: SizedBox(
            width: side,
            height: side,
            child: Center(
              child: busy
                  ? const AppBusyIndicator(
                      size: 22,
                      padding: EdgeInsets.zero,
                    )
                  : Icon(
                      active && selected ? (selectedIcon ?? icon) : icon,
                      size: 22,
                      color: color,
                    ),
            ),
          ),
        ),
      ),
    );

    final core = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: capsule),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppLayout.bottomNavBlurSigma,
            sigmaY: AppLayout.bottomNavBlurSigma,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(color: glassFill, shape: capsule),
            child: Material(type: MaterialType.transparency, child: button),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: core);
    }
    return core;
  }
}

/// Screen-absolute coordinates for the story assistant chrome action.
abstract final class AppBottomChromeMetrics {
  /// How far to shift floating chrome down so it stays on the physical screen
  /// bottom while [adjustResize] / Scaffold shortens the body for the IME.
  static double keyboardPinOffset(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom;

  /// Vertical center aligned with graph viewport end actions (「加一站」).
  static double assistantButtonBottom(BuildContext context) {
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    final graphFabCenter = viewBottom +
        AppLayout.bottomNavBottomInset +
        AppTheme.spaceSm +
        AppLayout.bottomNavHeight +
        AppTheme.spaceMd +
        AppCircleButton.fabDiameter / 2;
    return graphFabCenter - AppBottomNavIconCapsule.side / 2;
  }

  static const double assistantButtonRight = AppTheme.spaceMd;

  /// Width cleared on the right of canvas tool rows for the assistant capsule.
  static double assistantChromeReserveWidth() {
    return AppBottomNavIconCapsule.side + AppTheme.spaceSm;
  }

  static double graphEndActionsRight() {
    return AppTheme.spaceMd + assistantChromeReserveWidth();
  }

  static double dockedPanelBottom(BuildContext context) {
    return assistantButtonBottom(context) +
        AppBottomNavIconCapsule.side / 2 +
        AppTheme.spaceSm;
  }
}