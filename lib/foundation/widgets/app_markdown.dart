import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Themed, read-only Markdown. Business screens must use this, not [MarkdownBody].
class AppMarkdown extends StatelessWidget {
  const AppMarkdown(
    this.data, {
    super.key,
    this.role = AppTextRole.body,
    this.shrinkWrap = true,
  });

  final String data;
  final AppTextRole role;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final baseStyle = switch (role) {
      AppTextRole.body => theme.textTheme.bodyLarge,
      AppTextRole.caption => theme.textTheme.bodySmall,
      AppTextRole.compactBody => theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.35,
          ),
      _ => theme.textTheme.bodyLarge,
    };

    if (data.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return MarkdownBody(
      data: data,
      shrinkWrap: shrinkWrap,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: baseStyle,
        listBullet: baseStyle,
        code: baseStyle?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      selectable: false,
      softLineBreak: true,
      onTapLink: (_, _, _) {},
    );
  }
}