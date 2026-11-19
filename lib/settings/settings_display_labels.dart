import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/settings/settings_sections.dart';

/// Section name for the settings rail / bottom nav.
String settingsSectionLabel(AppStrings strings, SettingsSection section) {
  return switch (section) {
    SettingsSection.general => strings.settingsSectionGeneral,
    SettingsSection.appearance => strings.settingsSectionAppearance,
    SettingsSection.ai => strings.settingsSectionAi,
    SettingsSection.about => strings.settingsSectionAbout,
  };
}
