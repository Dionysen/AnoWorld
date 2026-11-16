import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/widgets.dart';

class AppearanceSettingsPanel extends StatelessWidget {
  const AppearanceSettingsPanel({super.key});

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
