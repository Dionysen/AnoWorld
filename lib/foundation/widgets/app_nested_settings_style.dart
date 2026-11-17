import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

/// Shared visuals for the second tier under a settings expand block.
abstract final class AppNestedSettingsStyle {
  static const double horizontalInset = AppTheme.spaceMd;
  static const double outlineAlpha = 0.58;

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