import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:anoworld/settings/settings_display_labels.dart';
import 'package:flutter/material.dart';

enum SettingsSection { general, appearance, ai, about }

extension SettingsSectionX on SettingsSection {
  String get id => name;

  IconData get icon => switch (this) {
        SettingsSection.general => Icons.tune_outlined,
        SettingsSection.appearance => Icons.palette_outlined,
        SettingsSection.ai => Icons.auto_awesome_outlined,
        SettingsSection.about => Icons.info_outline,
      };

  IconData get selectedIcon => switch (this) {
        SettingsSection.general => Icons.tune,
        SettingsSection.appearance => Icons.palette,
        SettingsSection.ai => Icons.auto_awesome,
        SettingsSection.about => Icons.info,
      };

  static SettingsSection fromId(String id) {
    return SettingsSection.values.firstWhere(
      (s) => s.id == id,
      orElse: () => SettingsSection.general,
    );
  }
}

List<AppNavItem> settingsNavItems(AppStrings strings) => [
      for (final section in SettingsSection.values)
        AppNavItem(
          id: section.id,
          label: settingsSectionLabel(strings, section),
          icon: section.icon,
          selectedIcon: section.selectedIcon,
        ),
    ];
