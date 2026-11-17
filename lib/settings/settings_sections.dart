import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:flutter/material.dart';

enum SettingsSection { general, appearance, presets, ai, about }

extension SettingsSectionX on SettingsSection {
  String get id => name;

  String get label => switch (this) {
        SettingsSection.general => '通用',
        SettingsSection.appearance => '外观',
        SettingsSection.presets => '预设',
        SettingsSection.ai => 'AI',
        SettingsSection.about => '关于',
      };

  IconData get icon => switch (this) {
        SettingsSection.general => Icons.tune_outlined,
        SettingsSection.appearance => Icons.palette_outlined,
        SettingsSection.presets => Icons.library_books_outlined,
        SettingsSection.ai => Icons.auto_awesome_outlined,
        SettingsSection.about => Icons.info_outline,
      };

  IconData get selectedIcon => switch (this) {
        SettingsSection.general => Icons.tune,
        SettingsSection.appearance => Icons.palette,
        SettingsSection.presets => Icons.library_books,
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

List<AppNavItem> get settingsNavItems => [
      for (final section in SettingsSection.values)
        AppNavItem(
          id: section.id,
          label: section.label,
          icon: section.icon,
          selectedIcon: section.selectedIcon,
        ),
    ];
