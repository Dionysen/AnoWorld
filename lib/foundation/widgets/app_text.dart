import 'package:flutter/material.dart';

enum AppTextRole { title, subtitle, body, caption, label }

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
      AppTextRole.title => theme.textTheme.titleLarge,
      AppTextRole.subtitle => theme.textTheme.titleMedium,
      AppTextRole.body => theme.textTheme.bodyLarge,
      AppTextRole.caption => theme.textTheme.bodySmall,
      AppTextRole.label => theme.textTheme.labelLarge,
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
