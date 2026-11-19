import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
import 'app_text_field.dart';

/// Centered prompt dialog (NativeTavern `AlertDialog` pattern, AnoWorld chrome).
Future<String?> showAppPromptDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? hint,
  String? confirmLabel,
  String? cancelLabel,
  bool autofocus = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _AppPromptDialog(
      title: title,
      label: label,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel ?? ctx.ui.confirm,
      cancelLabel: cancelLabel ?? ctx.ui.cancel,
      autofocus: autofocus,
    ),
  );
}

class _AppPromptDialog extends StatefulWidget {
  const _AppPromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.autofocus,
  });

  final String title;
  final String label;
  final String initial;
  final String? hint;
  final String confirmLabel;
  final String cancelLabel;
  final bool autofocus;

  @override
  State<_AppPromptDialog> createState() => _AppPromptDialogState();
}

class _AppPromptDialogState extends State<_AppPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.of(context);
    return AlertDialog(
      shape: tokens.shape(),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      title: AppText(widget.title, role: AppTextRole.subtitle),
      content: SizedBox(
        width: 320,
        child: AppTextField(
          label: widget.label,
          controller: _controller,
          hint: widget.hint,
          autofocus: widget.autofocus,
          onSubmitted: (_) => _confirm(),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        0,
        AppTheme.pagePadding,
        AppTheme.pagePadding,
      ),
      actions: [
        AppButton(
          label: widget.cancelLabel,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: widget.confirmLabel,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
