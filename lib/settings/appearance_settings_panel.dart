import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_font_picker.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = controller.appearance;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader('主题模式'),
            AppSegmented<AppThemeModeSetting>(
              value: current.mode,
              onChanged: (mode) {
                controller.updateAppearance(current.copyWith(mode: mode));
              },
              options: [
                for (final mode in AppThemeModeSetting.values)
                  AppSegmentOption(value: mode, label: mode.label),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader('界面'),
            AppFontPickerRow(
              label: '字体',
              description: '点按选择字体；电脑会列出本机已安装的字体，手机可导入字体文件。',
              fonts: controller.fontCatalog,
              selectedPath: current.fontPath,
              selectedLabel: controller.selectedFontLabel(),
              isLoading: controller.fontsLoading,
              onSelected: controller.selectFont,
              onImportPath: controller.importFontFromPath,
              onDeleteFont: controller.deleteImportedFont,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppSlider(
              label: '字体大小',
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
            const SizedBox(height: AppTheme.spaceMd),
            AppSlider(
              label: '圆角大小',
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
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader('配色'),
            const AppText(
              '选择一套内置配色；浅色/深色会各自取对应色板。',
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            for (var i = 0; i < AppThemePreset.values.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.spaceSm),
              AppListTile(
                title: AppThemePreset.values[i].label,
                subtitle: AppThemePreset.values[i].blurb,
                onTap: () {
                  controller.updateAppearance(
                    current.copyWith(preset: AppThemePreset.values[i]),
                  );
                },
                trailing: current.preset == AppThemePreset.values[i]
                    ? const AppText('使用中', role: AppTextRole.caption)
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }
}
