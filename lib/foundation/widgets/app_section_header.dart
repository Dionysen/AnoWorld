import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import 'app_page_gutter.dart';
import 'app_text.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(
    this.label, {
    super.key,
    this.subtitle,
    this.gutter = false,
  });

  final String label;

  /// Optional caption under the title. Keeps a tight gap to [label] and a
  /// larger margin below the block before following content.
  final String? subtitle;

  /// When true, apply [AppPageGutter] so the header aligns with flat list rows
  /// on edge-to-edge settings pages.
  final bool gutter;

  @override
  Widget build(BuildContext context) {
    Widget header = Padding(
      padding: EdgeInsets.only(
        bottom: subtitle == null ? AppTheme.spaceSm : AppTheme.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(label, role: AppTextRole.subtitle),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spaceXs),
            AppText(subtitle!, role: AppTextRole.caption),
          ],
        ],
      ),
    );
    if (gutter) header = AppPageGutter(child: header);
    return header;
  }
}
