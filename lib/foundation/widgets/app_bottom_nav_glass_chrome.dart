import 'dart:ui' show ImageFilter;

import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:flutter/material.dart';

/// Frosted glass shell matching [AppBottomNavIconCapsule] chrome.
class AppBottomNavGlassChrome extends StatelessWidget {
  const AppBottomNavGlassChrome({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassFill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.32 : 0.48,
    );
    final borderColor =
        theme.colorScheme.outline.withValues(alpha: isDark ? 0.45 : 0.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppLayout.bottomNavBlurSigma,
            sigmaY: AppLayout.bottomNavBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: glassFill),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}