import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_text.dart';

/// Encapsulated text field. Business code must not use [TextField] directly.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.obscureText = false,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(label, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceXs),
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
