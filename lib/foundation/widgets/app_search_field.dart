import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon_button.dart';

/// Compact search row for list screens (no separate label).
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.pagePadding,
      AppTheme.spaceSm,
      AppTheme.pagePadding,
      AppTheme.spaceSm,
    ),
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hasText = controller?.text.isNotEmpty == true;
    return Padding(
      padding: padding,
      child: SizedBox(
        height: AppTheme.buttonHeight,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            prefixIcon: const Icon(Icons.search, size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: AppTheme.buttonHeight,
              minHeight: AppTheme.buttonHeight,
            ),
            suffixIcon: hasText && onClear != null
                ? AppIconButton(
                    icon: Icons.close,
                    tooltip: '清除',
                    onPressed: onClear,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minHeight: AppTheme.buttonHeight,
            ),
          ),
        ),
      ),
    );
  }
}
