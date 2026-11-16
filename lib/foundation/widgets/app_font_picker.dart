import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../fonts/system_font.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_icon_button.dart';
import 'app_list_tile.dart';
import 'app_section_header.dart';
import 'app_text.dart';
import 'app_text_field.dart';

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
    this.onDeleteFont,
  });

  final String label;
  final String description;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '字体已导入到应用字体库。' : '无法导入该字体文件。')),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final query = ValueNotifier('');
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding,
                        0,
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
                        label: '搜索',
                        hint: '搜索字体',
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
                          label: '选择字体文件…',
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
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.pagePadding,
                              AppTheme.spaceSm,
                              AppTheme.pagePadding,
                              AppTheme.spaceLg,
                            ),
                            children: [
                              AppListTile(
                                title: '系统默认',
                                onTap: () {
                                  onSelected(null);
                                  Navigator.pop(context);
                                },
                                trailing: (selectedPath ?? '').isEmpty
                                    ? const AppText(
                                        '当前',
                                        role: AppTextRole.caption,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: AppTheme.spaceSm),
                              for (final font in filtered) ...[
                                AppListTile(
                                  title: font.family,
                                  subtitle: font.imported ? '已导入' : null,
                                  onTap: () {
                                    onSelected(font);
                                    Navigator.pop(context);
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (font.path == selectedPath)
                                        const AppText(
                                          '当前',
                                          role: AppTextRole.caption,
                                        ),
                                      if (font.imported &&
                                          onDeleteFont != null)
                                        AppIconButton(
                                          icon: Icons.delete_outline,
                                          tooltip: '从库中移除',
                                          onPressed: () async {
                                            final confirmed =
                                                await _confirmDelete(
                                              context,
                                              font.family,
                                            );
                                            if (confirmed != true ||
                                                !context.mounted) {
                                              return;
                                            }
                                            final ok =
                                                await onDeleteFont!(font);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  ok
                                                      ? '已从应用字体库中移除。'
                                                      : '无法删除该字体。',
                                                ),
                                              ),
                                            );
                                            if (ok) {
                                              Navigator.pop(context);
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spaceSm),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      query.dispose();
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String family) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppSectionHeader('删除字体？'),
                AppText(
                  '从应用字体库中移除「$family」以释放空间？',
                  role: AppTextRole.body,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '取消',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: AppButton(
                        label: '删除',
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      onTap: () => _openPicker(context),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: AppText(
          isLoading ? '加载字体…' : selectedLabel,
          role: AppTextRole.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}
