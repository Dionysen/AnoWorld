import 'package:flutter/material.dart';

import '../focus/app_keyboard.dart';
import '../theme/app_continuous_input_border.dart';
import '../theme/app_theme.dart';
import 'app_icon_button.dart';

/// Compact search row for list screens (no separate label).
///
/// Always a capsule (radius = field height / 2); ignores appearance corner
/// radius so it stays pill-shaped like the bottom nav chrome.
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

  /// Fixed field height; capsule radius is half of this.
  static const double height = AppTheme.buttonHeight;

  static BorderRadius get capsuleRadius =>
      BorderRadius.circular(height / 2);

  static AppContinuousInputBorder _border(Color color) {
    return AppContinuousInputBorder(
      borderRadius: capsuleRadius,
      borderSide: BorderSide(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasText = controller?.text.isNotEmpty == true;
    final outline = scheme.outline.withValues(alpha: 0.55);
    final focused = scheme.primary;

    return Padding(
      padding: padding,
      child: SizedBox(
        height: height,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onTapOutside: (_) => AppKeyboard.dismiss(),
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: _border(outline),
            enabledBorder: _border(outline),
            focusedBorder: _border(focused),
            prefixIcon: const Icon(Icons.search, size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: height,
              minHeight: height,
            ),
            suffixIcon: hasText && onClear != null
                ? AppIconButton(
                    icon: Icons.close,
                    tooltip: '清除',
                    onPressed: onClear,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minHeight: height,
            ),
          ),
        ),
      ),
    );
  }
}
