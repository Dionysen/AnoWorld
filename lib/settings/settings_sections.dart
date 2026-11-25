import 'package:flutter/material.dart';

/// Settings entries listed in the settings tab, each opening its own page.
enum SettingsSection {
  general,
  appearance,
  plotElements,
  ai,
  preset,
  generation,
  about,
}

extension SettingsSectionX on SettingsSection {
  String get id => name;

  IconData get icon => switch (this) {
    SettingsSection.general => Icons.tune_outlined,
    SettingsSection.appearance => Icons.palette_outlined,
    SettingsSection.plotElements => Icons.theater_comedy_outlined,
    SettingsSection.ai => Icons.smart_toy_outlined,
    SettingsSection.preset => Icons.style_outlined,
    SettingsSection.generation => Icons.movie_filter_outlined,
    SettingsSection.about => Icons.info_outline,
  };
}
