import 'package:flutter/material.dart';

/// Settings entries listed in the settings tab, each opening its own page.
enum SettingsSection { general, appearance, ai, about }

extension SettingsSectionX on SettingsSection {
  String get id => name;

  IconData get icon => switch (this) {
    SettingsSection.general => Icons.tune_outlined,
    SettingsSection.appearance => Icons.palette_outlined,
    SettingsSection.ai => Icons.auto_awesome_outlined,
    SettingsSection.about => Icons.info_outline,
  };
}
