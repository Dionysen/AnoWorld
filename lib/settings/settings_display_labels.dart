import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/settings/settings_sections.dart';

/// Section name for the settings rail / bottom nav.
String settingsSectionLabel(AppStrings strings, SettingsSection section) {
  return switch (section) {
    SettingsSection.general => strings.settingsSectionGeneral,
    SettingsSection.appearance => strings.settingsSectionAppearance,
    SettingsSection.ai => strings.settingsSectionAi,
    SettingsSection.generation => strings.settingsSectionGeneration,
    SettingsSection.about => strings.settingsSectionAbout,
  };
}

/// One-line hint under the section title on the settings hub list.
String settingsSectionHint(AppStrings strings, SettingsSection section) {
  return switch (section) {
    SettingsSection.general => strings.settingsSectionGeneralHint,
    SettingsSection.appearance => strings.settingsSectionAppearanceHint,
    SettingsSection.ai => strings.settingsSectionAiHint,
    SettingsSection.generation => strings.settingsSectionGenerationHint,
    SettingsSection.about => strings.settingsSectionAboutHint,
  };
}
