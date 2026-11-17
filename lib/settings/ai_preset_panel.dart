import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/settings/prompt_manager_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AiPresetPanel extends StatelessWidget {
  const AiPresetPanel({super.key});

  static String displayName(AIPreset preset) {
    if (!preset.isBuiltIn) return preset.name;
    return switch (preset.id) {
      'default' => '均衡',
      'creative' => '更发散',
      'precise' => '更克制',
      'deterministic' => '更稳定',
      'longform' => '偏长篇',
      'mirostat' => 'Mirostat 采样',
      _ => preset.name,
    };
  }

  static String? displaySubtitle(AIPreset preset) {
    final desc = preset.description?.trim();
    if (desc == null || desc.isEmpty) {
      final g = preset.generationSettings;
      return '温度 ${g.temperature} · 最长 ${g.maxTokens} token';
    }
    return switch (preset.id) {
      'default' => '日常写故事',
      'creative' => '想象力更大胆',
      'precise' => '少跑题、少废话',
      'deterministic' => '同样输入更接近同样结果',
      'longform' => '单次输出可以更长',
      'mirostat' => '按 Mirostat 调随机性',
      _ => desc,
    };
  }

  Future<void> _import(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked.isEmpty) return;
    final file = picked.single;
    try {
      final bytes = await file.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        _toast(context, '不是合法的预设文件');
        return;
      }
      if (!context.mounted) return;
      final preset =
          await AppScope.settingsOf(context).importAiPreset(decoded);
      if (!context.mounted) return;
      _toast(context, '已导入并套用：${preset.name}');
    } catch (error) {
      if (!context.mounted) return;
      _toast(context, '导入失败：$error');
    }
  }

  Future<void> _export(BuildContext context, AIPreset preset) async {
    final json = preset.toExportJson();
    final data = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
    await FilePicker.saveFile(
      dialogTitle: '导出预设',
      fileName: '${preset.name}.json',
      bytes: data,
    );
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    return showAppSheet<String>(
      context: context,
      size: AppSheetSize.half,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceSm,
            AppTheme.pagePadding,
            AppTheme.spaceMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(title),
              AppTextField(
                label: '名称',
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    Navigator.of(context).pop(controller.text.trim()),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              AppButton(
                label: '确定',
                expanded: true,
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final catalog = controller.aiPresets;
        final activeId = catalog.activePresetId;
        final builtIn =
            catalog.allPresets.where((p) => p.isBuiltIn).toList(growable: false);
        final custom = catalog.customPresets;
        final active = catalog.activePreset;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              'AI 预设',
              subtitle: '全局套用采样与提示词，与酒馆预设兼容',
            ),
            if (active != null)
              AppText(
                '当前：${displayName(active)}',
                role: AppTextRole.caption,
              ),
            const SizedBox(height: AppTheme.spaceSm),
            AppListTile(
              title: '提示词分段',
              subtitle: '开关与编辑各段内容',
              icon: Icons.reorder_outlined,
              trailing: const AppForwardIcon(),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const PromptManagerPage(),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: AppTheme.spaceSm,
              runSpacing: AppTheme.spaceSm,
              children: [
                AppButton(
                  label: '导入',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _import(context),
                ),
                AppButton(
                  label: '存为预设',
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    final name = await _askName(
                      context,
                      title: '存为预设',
                      initial: '我的预设',
                    );
                    if (name == null || name.isEmpty || !context.mounted) return;
                    try {
                      await controller.saveCurrentAsAiPreset(name);
                      if (!context.mounted) return;
                      _toast(context, '已保存：$name');
                    } catch (error) {
                      if (!context.mounted) return;
                      _toast(context, '$error');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            const AppSectionHeader('内置'),
            for (var i = 0; i < builtIn.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.spaceSm),
              _PresetTile(
                title: displayName(builtIn[i]),
                subtitle: displaySubtitle(builtIn[i]),
                active: builtIn[i].id == activeId,
                onApply: () async {
                  await controller.applyAiPreset(builtIn[i]);
                  if (!context.mounted) return;
                  _toast(context, '已套用：${displayName(builtIn[i])}');
                },
                onCopy: () async {
                  final name = await _askName(
                    context,
                    title: '复制为自定义',
                    initial: '${displayName(builtIn[i])} 副本',
                  );
                  if (name == null || name.isEmpty || !context.mounted) return;
                  final copy = await controller.copyAiPresetToCustom(
                    builtIn[i],
                    name: name,
                  );
                  await controller.applyAiPreset(copy);
                  if (!context.mounted) return;
                  _toast(context, '已创建：$name');
                },
              ),
            ],
            if (custom.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceLg),
              const AppSectionHeader('我的'),
              for (var i = 0; i < custom.length; i++) ...[
                if (i > 0) const SizedBox(height: AppTheme.spaceSm),
                _PresetTile(
                  title: custom[i].name,
                  subtitle: displaySubtitle(custom[i]),
                  active: custom[i].id == activeId,
                  onApply: () async {
                    await controller.applyAiPreset(custom[i]);
                    if (!context.mounted) return;
                    _toast(context, '已套用：${custom[i].name}');
                  },
                  onExport: () => _export(context, custom[i]),
                  onRename: () async {
                    final name = await _askName(
                      context,
                      title: '重命名',
                      initial: custom[i].name,
                    );
                    if (name == null ||
                        name.isEmpty ||
                        name == custom[i].name ||
                        !context.mounted) {
                      return;
                    }
                    await controller.renameCustomAiPreset(custom[i].id, name);
                    if (!context.mounted) return;
                    _toast(context, '已改名');
                  },
                  onDelete: () async {
                    await controller.deleteCustomAiPreset(custom[i].id);
                    if (!context.mounted) return;
                    _toast(context, '已删除');
                  },
                ),
              ],
            ] else ...[
              const SizedBox(height: AppTheme.spaceMd),
              const AppEmptyState(
                message: '还没有自定义预设',
                detail: '可从内置复制，或导入酒馆 JSON',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onApply,
    this.onCopy,
    this.onExport,
    this.onRename,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onApply;
  final VoidCallback? onCopy;
  final VoidCallback? onExport;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: title,
      subtitle: subtitle,
      icon: Icons.tune_outlined,
      trailing: active
          ? const AppText('当前', role: AppTextRole.caption)
          : const AppText('套用', role: AppTextRole.caption),
      onTap: onApply,
      onLongPress: (onCopy ?? onExport ?? onRename ?? onDelete) == null
          ? null
          : () => _showActions(context),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.half,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceSm,
            AppTheme.pagePadding,
            AppTheme.spaceMd,
          ),
          children: [
            if (onCopy != null)
              AppListTile(
                title: '复制为自定义',
                icon: Icons.content_copy_outlined,
                onTap: () {
                  Navigator.pop(context);
                  onCopy!();
                },
              ),
            if (onExport != null)
              AppListTile(
                title: '导出 JSON',
                icon: Icons.upload_outlined,
                onTap: () {
                  Navigator.pop(context);
                  onExport!();
                },
              ),
            if (onRename != null)
              AppListTile(
                title: '重命名',
                icon: Icons.drive_file_rename_outline,
                onTap: () {
                  Navigator.pop(context);
                  onRename!();
                },
              ),
            if (onDelete != null)
              AppListTile(
                title: '删除',
                icon: Icons.delete_outline,
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        );
      },
    );
  }
}