import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import 'app_text.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.label, {super.key, this.subtitle});

  final String label;

  /// Optional caption under the title. Keeps a tight gap to [label] and a
  /// larger margin below the block before following content.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  }
}
