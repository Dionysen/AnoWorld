import 'package:flutter/material.dart';

enum AppTextRole {
  pageTitle,
  title,
  subtitle,
  body,
  caption,
  label,
  /// One step below [body] (e.g. story-detail lorebook rows).
  compactBody,
  /// Entry title on compact rows; between [caption] and [label] in weight.
  compactLabel,
  /// Tag chip on story-detail lorebook rows.
  compactTag,
}

/// Themed text. Business screens should prefer this over raw [Text] styling.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.role = AppTextRole.body,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String data;
  final AppTextRole role;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = switch (role) {
      AppTextRole.pageTitle => theme.textTheme.headlineSmall,
      AppTextRole.title => theme.textTheme.titleLarge,
      AppTextRole.subtitle => theme.textTheme.titleMedium,
      AppTextRole.body => theme.textTheme.bodyLarge,
      AppTextRole.caption => theme.textTheme.bodySmall,
      AppTextRole.label => theme.textTheme.labelLarge,
      AppTextRole.compactBody => theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.35,
          ),
      AppTextRole.compactLabel => theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            height: 1.35,
          ),
      AppTextRole.compactTag => theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
            height: 1.2,
          ),
    };
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow ?? (maxLines == null ? null : TextOverflow.ellipsis),
      textAlign: textAlign,
    );
  }
}
