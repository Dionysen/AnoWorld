import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import 'app_text.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.detail,
    this.action,
  });

  final String message;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppText(
              message,
              role: AppTextRole.body,
              textAlign: TextAlign.center,
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppText(
                detail!,
                role: AppTextRole.caption,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
