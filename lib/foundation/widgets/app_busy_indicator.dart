import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact circular progress for title-bar / inline chrome.
///
/// Business pages must not use [CircularProgressIndicator] directly.
class AppBusyIndicator extends StatelessWidget {
  const AppBusyIndicator({
    super.key,
    this.size = 18,
    this.strokeWidth = 2,
    this.semanticLabel,
  });

  final double size;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: scheme.primary,
      ),
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs),
      child: ring,
    );
    if (semanticLabel == null) return padded;
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      child: padded,
    );
  }
}
