import 'package:flutter/material.dart';

import 'app_text.dart';

/// Collapsed preview for multi-line body copy; expansion state lives in the parent.
class AppExpandableText extends StatelessWidget {
  const AppExpandableText({
    super.key,
    required this.text,
    required this.expanded,
    this.previewLines = 3,
    this.role = AppTextRole.body,
  });

  final String text;
  final bool expanded;
  final int previewLines;
  final AppTextRole role;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppText(
      text,
      role: role,
      maxLines: expanded ? null : previewLines,
      overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }
}
