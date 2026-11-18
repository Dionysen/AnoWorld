import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_press_scale.dart';
import 'app_text.dart';

/// Grid-style cover card: image/cover area + optional title/subtitle footer.
///
/// When [title] is null, the cover fills the tile (no bottom bar) — used for
/// the library “add” control. That mode uses [AppPressScale] plus Ink hover /
/// press overlays so feedback stays visible.
class AppCoverTile extends StatelessWidget {
  const AppCoverTile({
    super.key,
    required this.cover,
    this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.overlay,
    this.compact = false,
    this.semanticLabel,
  });

  final Widget cover;

  /// When null, no footer — the whole tile is the [cover] button surface.
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Widget? overlay;
  final bool compact;
  final String? semanticLabel;

  static WidgetStateProperty<Color?> _inkOverlay(ColorScheme scheme) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return scheme.onSurface.withValues(alpha: 0.14);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return scheme.onSurface.withValues(alpha: 0.08);
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = AppUiTokens.of(context).shape();
    final base = scheme.surfaceContainerHighest;
    final color = selected
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), base)
        : base;
    final pad = compact ? AppTheme.spaceSm : AppTheme.spaceSm + 2;
    final showFooter = title != null;

    final Widget body;
    if (showFooter) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: compact ? 4 : 3, child: cover),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      title!,
                      role: AppTextRole.subtitle,
                      maxLines: 1,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      AppText(
                        subtitle!,
                        role: AppTextRole.caption,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          ?overlay,
        ],
      );
    } else {
      body = cover;
    }

    Widget child = Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: AppPressScale(
        enabled: onTap != null || onLongPress != null,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: shape,
          overlayColor: showFooter ? null : _inkOverlay(scheme),
          child: body,
        ),
      ),
    );

    if (semanticLabel != null) {
      return Semantics(
        button: true,
        label: semanticLabel,
        child: child,
      );
    }
    return child;
  }
}
