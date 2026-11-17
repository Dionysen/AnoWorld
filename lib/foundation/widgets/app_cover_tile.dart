import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_text.dart';

/// Grid-style cover card: image/cover area + title (+ optional subtitle).
class AppCoverTile extends StatelessWidget {
  const AppCoverTile({
    super.key,
    required this.cover,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.overlay,
    this.compact = false,
  });

  final Widget cover;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Widget? overlay;
  final bool compact;

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

    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: shape,
        child: Stack(
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
                        title,
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
        ),
      ),
    );
  }
}
