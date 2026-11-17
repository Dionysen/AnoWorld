import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_settings_expand_tile.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/settings/ai_generation_settings_panel.dart';
import 'package:anoworld/settings/prompt_manager_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

enum _PresetSubPanel { none, generation, prompts }

/// Global AI preset: picker + expandable generation / prompt blocks (NT-style).
class AiPresetPanel extends StatefulWidget {
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
    return switch (preset.id) {
      'default' => '日常写故事',
      'creative' => '想象力更大胆',
      'precise' => '少跑题、少废话',
      'deterministic' => '同样输入更接近同样结果',
      'longform' => '单次输出可以更长',
      'mirostat' => '按 Mirostat 调随机性',
      _ => preset.description?.trim().isNotEmpty == true
          ? preset.description!.trim()
          : null,
    };
  }

  @override
  State<AiPresetPanel> createState() => _AiPresetPanelState();
}

class _AiPresetPanelState extends State<AiPresetPanel> {
  _PresetSubPanel _expanded = _PresetSubPanel.none;

  void _toggle(_PresetSubPanel panel) {
    setState(() {
      _expanded = _expanded == panel ? _PresetSubPanel.none : panel;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openPresetPicker() async {
    final controller = AppScope.settingsOf(context);
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final catalog = controller.aiPresets;
            final activeId = catalog.activePresetId;
            final builtIn =
                catalog.allPresets.where((p) => p.isBuiltIn).toList();
            final custom = catalog.customPresets;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.spaceXs,
                    AppTheme.pagePadding,
                    AppTheme.spaceSm,
                  ),
                  child: AppSectionHeader(
                    '选择预设',
                    subtitle: '内置或已导入的自定义',
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      0,
                      AppTheme.pagePadding,
                      AppTheme.spaceMd,
                    ),
                    children: [
                      const AppText('内置', role: AppTextRole.caption),
                      const SizedBox(height: AppTheme.spaceSm),
                      for (final preset in builtIn)
                        _PresetPickRow(
                          title: AiPresetPanel.displayName(preset),
                          subtitle: AiPresetPanel.displaySubtitle(preset),
                          active: preset.id == activeId,
                          onTap: () async {
                            await controller.applyAiPreset(preset);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted) {
                              _toast('已套用：${AiPresetPanel.displayName(preset)}');
                            }
                          },
                        ),
                      if (custom.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceMd),
                        const AppText('我的', role: AppTextRole.caption),
                        const SizedBox(height: AppTheme.spaceSm),
                        for (final preset in custom)
                          _PresetPickRow(
                            title: preset.name,
                            subtitle: AiPresetPanel.displaySubtitle(preset),
                            active: preset.id == activeId,
                            onTap: () async {
                              await controller.applyAiPreset(preset);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) {
                                _toast('已套用：${preset.name}');
                              }
                            },
                            onLongPress: () => _presetActionsSheet(
                              sheetContext,
                              preset,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    0,
                    AppTheme.pagePadding,
                    AppTheme.spaceMd,
                  ),
                  child: Wrap(
                    spacing: AppTheme.spaceSm,
                    runSpacing: AppTheme.spaceSm,
                    children: [
                      AppButton(
                        label: '导入',
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _import();
                        },
                      ),
                      AppButton(
                        label: '存为预设',
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          final name = await _askName(
                            sheetContext,
                            title: '存为预设',
                            initial: '我的预设',
                          );
                          if (name == null || name.isEmpty) return;
                          await controller.saveCurrentAsAiPreset(name);
                          if (mounted) _toast('已保存：$name');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _presetActionsSheet(BuildContext context, AIPreset preset) async {
    final controller = AppScope.settingsOf(context);
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.half,
      builder: (ctx) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceSm,
            AppTheme.pagePadding,
            AppTheme.spaceMd,
          ),
          children: [
            AppListTile(
              title: '导出 JSON',
              icon: Icons.upload_outlined,
              onTap: () async {
                Navigator.pop(ctx);
                await _export(preset);
              },
            ),
            AppListTile(
              title: '重命名',
              icon: Icons.drive_file_rename_outline,
              onTap: () async {
                Navigator.pop(ctx);
                final name = await _askName(
                  context,
                  title: '重命名',
                  initial: preset.name,
                );
                if (name == null || name.isEmpty || name == preset.name) return;
                await controller.renameCustomAiPreset(preset.id, name);
                if (mounted) _toast('已改名');
              },
            ),
            AppListTile(
              title: '删除',
              icon: Icons.delete_outline,
              onTap: () async {
                Navigator.pop(ctx);
                await controller.deleteCustomAiPreset(preset.id);
                if (mounted) _toast('已删除');
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _import() async {
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
        if (mounted) _toast('不是合法的预设文件');
        return;
      }
      if (!mounted) return;
      final preset =
          await AppScope.settingsOf(context).importAiPreset(decoded);
      if (!mounted) return;
      _toast('已导入并套用：${preset.name}');
    } catch (error) {
      if (!mounted) return;
      _toast('导入失败：$error');
    }
  }

  Future<void> _export(AIPreset preset) async {
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

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.aiPresets.activePreset;
        final title = active == null
            ? '尚未选用'
            : AiPresetPanel.displayName(active);
        final sub = active == null
            ? '点一下选一套'
            : (AiPresetPanel.displaySubtitle(active) ??
                '温度 ${controller.ai.generation.temperature.toStringAsFixed(1)}');
        final genOpen = _expanded == _PresetSubPanel.generation;
        final promptsOpen = _expanded == _PresetSubPanel.prompts;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              '采样与提示词',
              subtitle: '与酒馆预设兼容，套用后写故事生效',
            ),
            AppListTile(
              title: title,
              subtitle: sub,
              icon: Icons.auto_awesome_outlined,
              trailing: const AppForwardIcon(),
              onTap: _openPresetPicker,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppSettingsExpandTile(
              title: '生成相关',
              subtitle: '温度、长度与高级采样',
              icon: Icons.tune_outlined,
              expanded: genOpen,
              onToggle: () => _toggle(_PresetSubPanel.generation),
              child: const AiGenerationSettingsPanel(),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppSettingsExpandTile(
              title: '提示词管理',
              subtitle: '分段顺序与文案',
              icon: Icons.reorder_outlined,
              expanded: promptsOpen,
              onToggle: () => _toggle(_PresetSubPanel.prompts),
              child: const PromptManagerPanel(),
            ),
          ],
        );
      },
    );
  }
}

class _PresetPickRow extends StatelessWidget {
  const _PresetPickRow({
    required this.title,
    required this.onTap,
    required this.active,
    this.subtitle,
    this.onLongPress,
  });

  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: AppListTile(
        title: title,
        subtitle: subtitle,
        icon: Icons.bookmark_outline,
        trailing: active
            ? const AppText('当前', role: AppTextRole.caption)
            : null,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}