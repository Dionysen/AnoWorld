import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_text.dart';

/// Select control laid out like [AppTextField]: caption label above, then a
/// value box matching [AppTheme.buttonHeight] (optional [trailing] same height).
class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final String? hint;
  final VoidCallback? onTap;

  /// Drawn on the same row as the value box (e.g. probe button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    final shape = tokens.shape(
      side: BorderSide(color: theme.colorScheme.outline),
    );
    final display = value.trim().isEmpty ? (hint ?? '') : value;
    final empty = value.trim().isEmpty;

    final field = SizedBox(
      height: AppTheme.buttonHeight,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.fieldPadding.horizontal / 2,
              vertical: AppTheme.spaceSm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: empty
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(label, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceXs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: field),
            if (trailing != null) ...[
              SizedBox(width: tokens.spaceInline),
              SizedBox(height: AppTheme.buttonHeight, child: trailing),
            ],
          ],
        ),
      ],
    );
  }
}
