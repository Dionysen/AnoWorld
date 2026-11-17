import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

/// Shared metrics for the second tier under a settings expand block.
///
/// Nested [AppListTile] / [AppSlider] stay flat (extra leading indent only).
/// [AppSurface](nested: true) still uses a light outlined panel for prose blocks.
abstract final class AppNestedSettingsStyle {
  static const double horizontalInset = 0;
  static const double outlineAlpha = 0.58;
  static const double contentIndent = AppTheme.spaceMd;

  static Color fill(ColorScheme scheme) => scheme.surfaceContainer;

  static ShapeBorder itemShape(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppUiTokens.of(context).shape(
      side: BorderSide(
        color: scheme.outline.withValues(alpha: outlineAlpha),
      ),
    );
  }
}
