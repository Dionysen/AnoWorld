import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../fonts/system_font.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_icon_button.dart';
import 'app_list_tile.dart';
import 'app_section_header.dart';
import 'app_sheet.dart';
import 'app_text.dart';
import 'app_text_field.dart';
import 'app_toast.dart';

/// Font picker: system/imported list, search, and file import (NativeTavern-style).
class AppFontPickerRow extends StatelessWidget {
  const AppFontPickerRow({
    super.key,
    required this.label,
    required this.description,
    required this.fonts,
    required this.selectedPath,
    required this.selectedLabel,
    required this.isLoading,
    required this.onSelected,
    required this.onImportPath,
    this.icon = Icons.text_fields,
    this.onDeleteFont,
  });

  final String label;
  final String description;
  final IconData icon;
  final List<SystemFont> fonts;
  final String? selectedPath;
  final String selectedLabel;
  final bool isLoading;
  final ValueChanged<SystemFont?> onSelected;
  final Future<bool> Function(String path) onImportPath;
  final Future<bool> Function(SystemFont font)? onDeleteFont;

  Future<void> _import(BuildContext context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf', 'ttc', 'otc'],
    );
    final path = file?.path;
    if (path == null || path.isEmpty) return;
    final ok = await onImportPath(path);
    if (!context.mounted) return;
    final ui = context.ui;
    showAppToast(
      context,
      ok ? ui.fontImportDone : ui.fontImportFailed,
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final query = ValueNotifier('');
    try {
      await showAppSheet<void>(
        context: context,
        size: AppSheetSize.half,
        builder: (context) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  AppTheme.spaceXs,
                  AppTheme.pagePadding,
                  AppTheme.spaceSm,
                ),
                child: AppSectionHeader(label),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.pagePadding,
                ),
                child: AppTextField(
                  label: context.ui.search,
                  hint: context.ui.searchFonts,
                  onChanged: (value) => query.value = value.trim(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  AppTheme.spaceSm,
                  AppTheme.pagePadding,
                  AppTheme.spaceXs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton(
                    label: context.ui.fontPickFile,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _import(context),
                  ),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: query,
                  builder: (context, filter, _) {
                    final lower = filter.toLowerCase();
                    final filtered = filter.isEmpty
                        ? fonts
                        : fonts
                            .where(
                              (f) =>
                                  f.family.toLowerCase().contains(lower),
                            )
                            .toList();
                    return ListView(
                      padding: const EdgeInsets.only(
                        top: AppTheme.spaceSm,
                        bottom: AppTheme.spaceLg,
                      ),
                      children: [
                        AppListTile(
                          title: context.ui.fontSystemDefault,
                          icon: Icons.phone_android_outlined,
                          onTap: () {
                            onSelected(null);
                            Navigator.pop(context);
                          },
                          trailing: (selectedPath ?? '').isEmpty
                              ? AppText(
                                  context.ui.currentBadge,
                                  role: AppTextRole.caption,
                                )
                              : null,
                        ),
                        for (final font in filtered)
                          AppListTile(
                            title: font.family,
                            subtitle:
                                font.imported ? context.ui.fontImported : null,
                            icon: font.imported
                                ? Icons.font_download_outlined
                                : Icons.text_fields,
                            onTap: () {
                              onSelected(font);
                              Navigator.pop(context);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (font.path == selectedPath)
                                  AppText(
                                    context.ui.currentBadge,
                                    role: AppTextRole.caption,
                                  ),
                                if (font.imported && onDeleteFont != null)
                                  AppIconButton(
                                    icon: Icons.delete_outline,
                                    tooltip: context.ui.fontRemoveAction,
                                    danger: true,
                                    onPressed: () async {
                                      final confirmed = await _confirmDelete(
                                        context,
                                        font.family,
                                      );
                                      if (confirmed != true ||
                                          !context.mounted) {
                                        return;
                                      }
                                      final ok = await onDeleteFont!(font);
                                      if (!context.mounted) return;
                                      final ui = context.ui;
                                      showAppToast(
                                        context,
                                        ok
                                            ? ui.fontRemoved
                                            : ui.fontRemoveFailed,
                                      );
                                      if (ok) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    } finally {
      query.dispose();
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String family) {
    return showAppSheet<bool>(
      context: context,
      builder: (context) {
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
              AppSectionHeader(context.ui.fontDeleteTitle),
              AppText(
                context.ui.fontDeleteDetail(family),
                role: AppTextRole.body,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.ui.cancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: AppButton(
                      label: context.ui.delete,
                      variant: AppButtonVariant.danger,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: label,
      subtitle: description,
      icon: icon,
      onTap: () => _openPicker(context),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: AppText(
          isLoading ? context.ui.fontLoading : selectedLabel,
          role: AppTextRole.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}
