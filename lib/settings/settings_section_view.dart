import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/about_panel.dart';
import 'package:anoworld/settings/ai_settings_panel.dart';
import 'package:anoworld/settings/appearance_settings_panel.dart';
import 'package:anoworld/settings/general_settings_panel.dart';
import 'package:anoworld/settings/settings_display_labels.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/widgets.dart';

/// One settings section as a page of its own (no section rail).
///
/// The settings tab lists the sections flat and opens them here: pushed on narrow
/// windows, hosted in the detail column on wide ones.
class SettingsSectionView extends StatelessWidget {
  const SettingsSectionView({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: settingsSectionLabel(context.strings, section),
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(children: [_bodyFor(section)]),
    );
  }
}

Widget _bodyFor(SettingsSection section) {
  return switch (section) {
    SettingsSection.general => const GeneralSettingsPanel(),
    SettingsSection.appearance => const AppearanceSettingsPanel(),
    SettingsSection.ai => const AiSettingsPanel(),
    SettingsSection.about => const AboutPanel(),
  };
}
