import 'package:flutter/material.dart';

import '../focus/app_keyboard.dart';
import '../theme/app_theme.dart';
import 'app_text.dart';

/// Encapsulated text field. Business code must not use [TextField] directly.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.obscureText = false,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      onTapOutside: (_) => AppKeyboard.dismiss(),
      obscureText: obscureText,
      keyboardType: keyboardType ??
          (maxLines != 1 ? TextInputType.multiline : null),
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(hintText: hint),
    );
    if (label.isEmpty) return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(label, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceXs),
        field,
      ],
    );
  }
}
