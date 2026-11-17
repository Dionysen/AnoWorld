import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_disclosure_icon.dart';
import 'app_list_tile.dart';
import 'app_section_header.dart';
import 'app_sheet.dart';
import 'app_text.dart';
import 'app_text_field.dart';

/// Flat settings row (NT-style): icon + title/subtitle on the left, value on
/// the right. Tap opens a sheet to edit the string.
class AppTextEditTile extends StatelessWidget {
  const AppTextEditTile({
    super.key,
    required this.title,
    required this.value,
    required this.onSubmitted,
    this.subtitle,
    this.icon,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.minLines,
    this.maxLines = 1,
    this.emptyLabel = '未填写',
    this.nested = false,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String value;
  final ValueChanged<String> onSubmitted;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? minLines;
  final int? maxLines;
  final String emptyLabel;
  final bool nested;
  final bool showDivider;

  static String displayValue(
    String value, {
    required bool obscureText,
    required String emptyLabel,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return emptyLabel;
    if (!obscureText) return trimmed;
    if (trimmed.length <= 4) return '••••';
    return '••••${trimmed.substring(trimmed.length - 4)}';
  }

  Future<void> _open(BuildContext context) async {
    final next = await showAppTextEditSheet(
      context: context,
      title: title,
      subtitle: subtitle,
      initialValue: value,
      hint: hint,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines ?? 1,
    );
    if (next == null) return;
    onSubmitted(next);
  }

  @override
  Widget build(BuildContext context) {
    final shown = displayValue(
      value,
      obscureText: obscureText,
      emptyLabel: emptyLabel,
    );
    return AppListTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      nested: nested,
      showDivider: showDivider,
      onTap: () => _open(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: AppText(
              shown,
              role: AppTextRole.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: AppTheme.spaceXs),
          const AppForwardIcon(),
        ],
      ),
    );
  }
}

/// Opens a compact sheet to edit a string (used by [AppTextEditTile]).
Future<String?> showAppTextEditSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required String initialValue,
  String? hint,
  bool obscureText = false,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  int? minLines,
  int maxLines = 1,
}) {
  return showAppSheet<String>(
    context: context,
    size: AppSheetSize.compact,
    builder: (sheetContext) {
      return _AppTextEditSheetBody(
        title: title,
        subtitle: subtitle,
        initialValue: initialValue,
        hint: hint,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        minLines: minLines,
        maxLines: maxLines,
      );
    },
  );
}

class _AppTextEditSheetBody extends StatefulWidget {
  const _AppTextEditSheetBody({
    required this.title,
    required this.initialValue,
    this.subtitle,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.minLines,
    this.maxLines = 1,
  });

  final String title;
  final String? subtitle;
  final String initialValue;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? minLines;
  final int maxLines;

  @override
  State<_AppTextEditSheetBody> createState() => _AppTextEditSheetBodyState();
}

class _AppTextEditSheetBodyState extends State<_AppTextEditSheetBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.spaceXs,
        AppTheme.pagePadding,
        AppTheme.spaceMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(widget.title, subtitle: widget.subtitle),
          AppTextField(
            label: '',
            controller: _controller,
            hint: widget.hint,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction ?? TextInputAction.done,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '取消',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: AppButton(
                  label: '保存',
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
