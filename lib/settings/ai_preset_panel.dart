import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_confirm_sheet.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/settings/ai_generation_settings_panel.dart';
import 'package:anoworld/settings/prompt_manager_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Global AI preset: current preset, its actions, sampling and prompt sections.
class AiPresetPanel extends StatefulWidget {
  const AiPresetPanel({super.key});

  static String displayName(AppStrings strings, AIPreset preset) {
    if (!preset.isBuiltIn) return preset.name;
    return switch (preset.id) {
      'default' => strings.presetDefaultName,
      'creative' => strings.presetCreativeName,
      'precise' => strings.presetPreciseName,
      'deterministic' => strings.presetDeterministicName,
      'longform' => strings.presetLongformName,
      'mirostat' => strings.presetMirostatName,
      _ => preset.name,
    };
  }

  static String? displaySubtitle(AppStrings strings, AIPreset preset) {
    return switch (preset.id) {
      'default' => strings.presetDefaultHint,
      'creative' => strings.presetCreativeHint,
      'precise' => strings.presetPreciseHint,
      'deterministic' => strings.presetDeterministicHint,
      'longform' => strings.presetLongformHint,
      'mirostat' => strings.presetMirostatHint,
      _ => preset.description?.trim().isNotEmpty == true
          ? preset.description!.trim()
          : null,
    };
  }

  @override
  State<AiPresetPanel> createState() => _AiPresetPanelState();
}

class _AiPresetPanelState extends State<AiPresetPanel> {
  void _toast(String message) {
    showAppToast(context, message);
  }

  Future<void> _openPresetPicker() async {
    final strings = context.strings;
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.spaceXs,
                    AppTheme.pagePadding,
                    AppTheme.spaceSm,
                  ),
                  child: AppSectionHeader(
                    strings.pickPresetTitle,
                    subtitle: strings.pickPresetHint,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      0,
                      0,
                      AppTheme.spaceMd,
                    ),
                    children: [
                      AppPageGutter(
                        child: AppText(
                          strings.presetBuiltInGroup,
                          role: AppTextRole.caption,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      for (final preset in builtIn)
                        _PresetPickRow(
                          title: AiPresetPanel.displayName(strings, preset),
                          subtitle:
                              AiPresetPanel.displaySubtitle(strings, preset),
                          active: preset.id == activeId,
                          onTap: () async {
                            await controller.applyAiPreset(preset);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted) {
                              _toast(strings.presetApplied(
                                AiPresetPanel.displayName(strings, preset),
                              ));
                            }
                          },
                        ),
                      if (custom.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceMd),
                        AppPageGutter(
                          child: AppText(
                            strings.presetMineGroup,
                            role: AppTextRole.caption,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        for (final preset in custom)
                          _PresetPickRow(
                            title: preset.name,
                            subtitle:
                                AiPresetPanel.displaySubtitle(strings, preset),
                            active: preset.id == activeId,
                            onTap: () async {
                              await controller.applyAiPreset(preset);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) {
                                _toast(strings.presetApplied(preset.name));
                              }
                            },
                          ),
                      ],
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

  Future<void> _create() async {
    final strings = context.strings;
    final name = await _askName(
      context,
      title: strings.presetNewAction,
      initial: strings.presetNewName,
    );
    if (name == null || name.isEmpty || !mounted) return;
    final preset = await AppScope.settingsOf(context).createAiPreset(name);
    if (!mounted) return;
    _toast(strings.presetCreated(preset.name));
  }

  Future<void> _saveCurrent() async {
    final strings = context.strings;
    final name = await _askName(
      context,
      title: strings.presetSaveCurrentAction,
      initial: strings.myPresetName,
    );
    if (name == null || name.isEmpty || !mounted) return;
    await AppScope.settingsOf(context).saveCurrentAsAiPreset(name);
    if (!mounted) return;
    _toast(strings.presetSaved(name));
  }

  Future<void> _renameCurrent() async {
    final strings = context.strings;
    final controller = AppScope.settingsOf(context);
    final active = controller.aiPresets.activePreset;
    if (active == null) {
      _toast(strings.presetNoActive);
      return;
    }
    if (active.isBuiltIn) {
      _toast(strings.presetRenameBuiltInHint);
      return;
    }
    final name = await _askName(
      context,
      title: strings.presetRenameTitle,
      initial: active.name,
    );
    if (name == null || name.isEmpty || name == active.name || !mounted) {
      return;
    }
    await controller.renameCustomAiPreset(active.id, name);
    if (!mounted) return;
    _toast(strings.presetRenamed(name));
  }

  Future<void> _deleteCurrent() async {
    final strings = context.strings;
    final controller = AppScope.settingsOf(context);
    final active = controller.aiPresets.activePreset;
    if (active == null) {
      _toast(strings.presetNoActive);
      return;
    }
    if (active.isBuiltIn) {
      _toast(strings.presetDeleteBuiltInHint);
      return;
    }
    final confirmed = await showAppConfirmSheet(
      context,
      title: strings.presetDeleteTitle(active.name),
      detail: strings.presetDeleteDetail,
      confirmLabel: strings.delete,
    );
    if (!confirmed || !mounted) return;
    await controller.deleteCustomAiPreset(active.id);
    if (!mounted) return;
    _toast(strings.presetDeleted);
  }

  Future<void> _exportCurrent() async {
    final strings = context.strings;
    final controller = AppScope.settingsOf(context);
    final active = controller.aiPresets.activePreset;
    if (active == null) {
      _toast(strings.presetNoActive);
      return;
    }
    // Export what the user actually sees: live sampling + prompt order.
    final snapshot = active.copyWith(
      generationSettings: controller.ai.generation,
      promptManagerConfig: controller.aiPresets.promptManager,
    );
    await _export(snapshot);
  }

  Future<void> _restorePromptOrder() async {
    final strings = context.strings;
    final controller = AppScope.settingsOf(context);
    await controller.updatePromptManager(
      controller.aiPresets.promptManager.restoreDefaultOrder(),
    );
    if (!mounted) return;
    AppLog.instance.info('恢复预设提示词默认顺序', tag: 'ai.preset');
    _toast(strings.presetOrderRestored);
  }

  Future<void> _import() async {
    final strings = context.strings;
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
        if (mounted) _toast(strings.invalidPresetFile);
        return;
      }
      if (!mounted) return;
      final preset =
          await AppScope.settingsOf(context).importAiPreset(decoded);
      AppLog.instance.info('导入预设：${preset.name}', tag: 'ai.preset');
      if (!mounted) return;
      _toast(strings.presetImported(preset.name));
    } catch (error, stack) {
      AppLog.instance.error(
        '导入预设失败',
        tag: 'ai.preset',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      _toast(strings.presetImportFailed(error));
    }
  }

  Future<void> _export(AIPreset preset) async {
    final strings = context.strings;
    final json = preset.toExportJson();
    final data = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
    await FilePicker.saveFile(
      dialogTitle: strings.exportPresetDialog,
      fileName: '${preset.name}.json',
      bytes: data,
    );
    AppLog.instance.info('导出预设：${preset.name}', tag: 'ai.preset');
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String initial,
  }) async {
    final strings = context.strings;
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
                label: strings.nameLabel,
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    Navigator.of(context).pop(controller.text.trim()),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              AppButton(
                label: strings.confirmAction,
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

  Widget _buildActions() {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Wrap(
        spacing: AppTheme.spaceSm,
        runSpacing: AppTheme.spaceSm,
        children: [
          AppIconButton(
            icon: Icons.add,
            tooltip: strings.presetNewAction,
            onPressed: _create,
          ),
          AppIconButton(
            icon: Icons.bookmark_add_outlined,
            tooltip: strings.presetSaveCurrentAction,
            onPressed: _saveCurrent,
          ),
          AppIconButton(
            icon: Icons.drive_file_rename_outline,
            tooltip: strings.presetRenameAction,
            onPressed: _renameCurrent,
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: strings.presetDeleteAction,
            danger: true,
            onPressed: _deleteCurrent,
          ),
          AppIconButton(
            icon: Icons.file_download_outlined,
            tooltip: strings.presetImportAction,
            onPressed: _import,
          ),
          AppIconButton(
            icon: Icons.file_upload_outlined,
            tooltip: strings.presetExportAction,
            onPressed: _exportCurrent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.aiPresets.activePreset;
        final presetName = active == null
            ? strings.presetNotChosen
            : AiPresetPanel.displayName(strings, active);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppTheme.spaceMd),
            _buildActions(),
            const SizedBox(height: AppTheme.spaceMd),
            AppListTile(
              title: presetName,
              subtitle: strings.presetRowHint,
              icon: Icons.auto_awesome_outlined,
              onTap: _openPresetPicker,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(strings.samplingSection, gutter: true),
            const AiGenerationSettingsPanel(),
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(
              strings.presetPromptsSection,
              gutter: true,
              trailing: AppIconButton(
                icon: Icons.restart_alt_outlined,
                tooltip: strings.presetRestoreOrderAction,
                onPressed: _restorePromptOrder,
              ),
            ),
            const PromptManagerPanel(),
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
  });

  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: title,
      subtitle: subtitle,
      icon: Icons.bookmark_outline,
      trailing: active
          ? AppText(
              context.strings.currentTag,
              role: AppTextRole.caption,
            )
          : null,
      onTap: onTap,
    );
  }
}
