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
    this.trailing,
  });

  final String label;

  /// Optional caption under the title. Keeps a tight gap to [label] and a
  /// larger margin below the block before following content.
  final String? subtitle;

  /// When true, apply [AppPageGutter] so the header aligns with flat list rows
  /// on edge-to-edge settings pages.
  final bool gutter;

  /// Control aligned to the right of [label] (icon button, switch, …).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final labelText = AppText(label, role: AppTextRole.subtitle);
    Widget header = Padding(
      padding: EdgeInsets.only(
        bottom: subtitle == null ? AppTheme.spaceSm : AppTheme.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trailing == null)
            labelText
          else
            Row(
              children: [
                Expanded(child: labelText),
                // Keep actions reachable on narrow widths without overflowing.
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: trailing!,
                    ),
                  ),
                ),
              ],
            ),
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
