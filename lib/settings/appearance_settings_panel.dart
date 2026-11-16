import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/theme/theme_color_pack.dart';
import 'package:anoworld/foundation/theme/theme_preset_labels.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_color_picker.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_font_picker.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

class AppearanceSettingsPanel extends StatefulWidget {
  const AppearanceSettingsPanel({super.key});

  @override
  State<AppearanceSettingsPanel> createState() =>
      _AppearanceSettingsPanelState();
}

class _AppearanceSettingsPanelState extends State<AppearanceSettingsPanel> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.settingsOf(context).ensureFontsLoaded();
    });
  }

  Future<void> _pickToken(
    SettingsController controller,
    ThemeToken token,
  ) async {
    final next = await showAppColorPicker(
      context,
      initialColor: Color(controller.activeTokens.valueOf(token)),
      title: token.label,
    );
    if (next == null || !mounted) return;
    await controller.updateToken(token, next.toARGB32());
  }

  Future<void> _openThemePackSheet(SettingsController controller) async {
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final appearance = controller.appearance;
            final packs = appearance.colorPacks;
            final activePack = controller.activePack;
            final activeMatches = activePack != null &&
                activePack.tokens == controller.activeTokens;
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.spaceXs,
                    AppTheme.pagePadding,
                    AppTheme.spaceSm,
                  ),
                  child: AppSectionHeader('主题预设'),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      AppTheme.spaceSm,
                      AppTheme.pagePadding,
                      AppTheme.spaceLg,
                    ),
                    itemCount: packs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spaceGroup),
                    itemBuilder: (context, index) {
                      final pack = packs[index];
                      final isActive = activeMatches &&
                          pack.id == controller.activePackId;
                      return AppListTile(
                        title: _packTitle(pack),
                        icon: _packIcon(pack),
                        onTap: () async {
                          await controller.applyPack(pack.id);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PackTrailing(
                              packId: pack.id,
                              lightPackId: appearance.lightPackId,
                              darkPackId: appearance.darkPackId,
                              isActive: isActive,
                            ),
                            if (!pack.isBuiltIn)
                              AppIconButton(
                                icon: Icons.more_horiz,
                                tooltip: '管理',
                                onPressed: () =>
                                    _customPackMenu(controller, pack),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openCustomColorsSheet(SettingsController controller) async {
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
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
                  child: AppSectionHeader('自定义颜色'),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      0,
                      AppTheme.pagePadding,
                      AppTheme.spaceSm,
                    ),
                    itemCount: ThemeToken.values.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spaceGroup),
                    itemBuilder: (context, index) {
                      final token = ThemeToken.values[index];
                      return AppListTile(
                        title: token.label,
                        subtitle: token.description,
                        icon: token.icon,
                        onTap: () => _pickToken(controller, token),
                        trailing: _ColorSwatch(
                          color: Color(
                            controller.activeTokens.valueOf(token),
                          ),
                          onTap: () => _pickToken(controller, token),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.spaceSm,
                    AppTheme.pagePadding,
                    AppTheme.spaceMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: '保存为主题',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => _saveAsTheme(controller),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: AppButton(
                          label: '恢复默认',
                          variant: AppButtonVariant.secondary,
                          onPressed: controller.restoreDefaults,
                        ),
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

  Future<void> _saveAsTheme(SettingsController controller) async {
    final name = await _promptName(
      title: '保存为主题颜色',
      initialName: '主题${controller.nextDefaultThemeNumber()}',
    );
    if (name == null || !mounted) return;
    await controller.saveCurrentAsTheme(name);
  }

  Future<String?> _promptName({
    required String title,
    required String initialName,
  }) async {
    final text = TextEditingController(text: initialName);
    text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.length,
    );
    try {
      return await showAppSheet<String>(
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
                AppSectionHeader(title),
                AppTextField(
                  label: '主题名称',
                  controller: text,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '取消',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: AppButton(
                        label: '保存',
                        onPressed: () {
                          final trimmed = text.text.trim();
                          if (trimmed.isEmpty) return;
                          Navigator.pop(context, trimmed);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } finally {
      text.dispose();
    }
  }

  Future<void> _customPackMenu(
    SettingsController controller,
    ThemeColorPack pack,
  ) async {
    if (pack.isBuiltIn) return;
    final action = await showAppSheet<_PackMenuAction>(
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
              AppSectionHeader(pack.name),
              AppListTile(
                title: '重命名',
                icon: Icons.drive_file_rename_outline,
                onTap: () => Navigator.pop(context, _PackMenuAction.rename),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppListTile(
                title: '复制',
                icon: Icons.copy_outlined,
                onTap: () => Navigator.pop(context, _PackMenuAction.copy),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppListTile(
                title: '删除',
                icon: Icons.delete_outline,
                onTap: () => Navigator.pop(context, _PackMenuAction.delete),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _PackMenuAction.rename:
        final name = await _promptName(
          title: '重命名主题',
          initialName: pack.name,
        );
        if (name == null || !mounted) return;
        await controller.renameCustomPack(pack.id, name);
      case _PackMenuAction.copy:
        await controller.copyCustomPack(pack.id, '${pack.name} 副本');
      case _PackMenuAction.delete:
        final confirmed = await showAppSheet<bool>(
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
                  const AppSectionHeader('删除主题？'),
                  AppText(
                    '删除「${pack.name}」后无法恢复。',
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
            );
          },
        );
        if (confirmed != true || !mounted) return;
        await controller.deleteCustomPack(pack.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = controller.appearance;
        final activePack = controller.activePack;
        final activeMatches =
            activePack != null && activePack.tokens == controller.activeTokens;
        final presetTrailing = activePack != null && activeMatches
            ? _packTitle(activePack)
            : '自定义';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader('主题模式'),
            AppSegmented<AppThemeModeSetting>(
              value: current.mode,
              onChanged: controller.setThemeMode,
              options: [
                for (final mode in AppThemeModeSetting.values)
                  AppSegmentOption(
                    value: mode,
                    label: mode.label,
                    icon: mode.icon,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader('主题颜色'),
            const SizedBox(height: AppTheme.spaceGroup),
            AppListTile(
              title: '主题预设',
              subtitle: '浅色与深色各记一套',
              icon: Icons.style_outlined,
              onTap: () => _openThemePackSheet(controller),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: AppText(
                  presetTrailing,
                  role: AppTextRole.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceGroup),
            AppListTile(
              title: '自定义颜色',
              subtitle: '调整当前配色',
              icon: Icons.colorize_outlined,
              onTap: () => _openCustomColorsSheet(controller),
              trailing: const AppForwardIcon(),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader('界面'),
            AppFontPickerRow(
              label: '字体',
              description: '系统字体或导入文件',
              icon: Icons.text_fields,
              fonts: controller.fontCatalog,
              selectedPath: current.fontPath,
              selectedLabel: controller.selectedFontLabel(),
              isLoading: controller.fontsLoading,
              onSelected: controller.selectFont,
              onImportPath: controller.importFontFromPath,
              onDeleteFont: controller.deleteImportedFont,
            ),
            const SizedBox(height: AppTheme.spaceGroup),
            AppSlider(
              label: '字体大小',
              icon: Icons.format_size,
              value: current.fontSize,
              min: AppearanceUiRange.fontSizeMin,
              max: AppearanceUiRange.fontSizeMax,
              step: AppearanceUiRange.fontSizeStep,
              valueText: (v) =>
                  '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} px',
              onChanged: (size) {
                controller.updateAppearance(
                  current.copyWith(fontSize: size),
                );
              },
            ),
            const SizedBox(height: AppTheme.spaceGroup),
            AppSlider(
              label: '圆角大小',
              icon: Icons.rounded_corner,
              value: current.cornerRadius,
              min: AppearanceUiRange.cornerRadiusMin,
              max: AppearanceUiRange.cornerRadiusMax,
              step: AppearanceUiRange.cornerRadiusStep,
              valueText: (v) => '${v.round()} px',
              onChanged: (radius) {
                controller.updateAppearance(
                  current.copyWith(cornerRadius: radius),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

enum _PackMenuAction { rename, copy, delete }

String _packTitle(ThemeColorPack pack) {
  final preset = pack.builtInPreset;
  if (preset != null) return preset.label;
  return pack.name;
}

IconData _packIcon(ThemeColorPack pack) {
  final preset = pack.builtInPreset;
  if (preset != null) return preset.icon;
  return Icons.bookmark_outline;
}

class _PackTrailing extends StatelessWidget {
  const _PackTrailing({
    required this.packId,
    required this.lightPackId,
    required this.darkPackId,
    required this.isActive,
  });

  final String packId;
  final String lightPackId;
  final String darkPackId;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final roles = <String>[
      if (packId == lightPackId) '亮色',
      if (packId == darkPackId) '暗色',
    ];
    if (roles.isEmpty && !isActive) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < roles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.spaceXs),
          AppText(roles[i], role: AppTextRole.caption),
        ],
        if (isActive) ...[
          if (roles.isNotEmpty) const SizedBox(width: AppTheme.spaceXs),
          const AppText('使用中', role: AppTextRole.caption),
        ],
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppUiTokens.of(context).shape(
      side: BorderSide(color: theme.colorScheme.outline),
    );
    return Material(
      color: color,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: const SizedBox(width: 28, height: 28),
      ),
    );
  }
}
