import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:anoworld/settings/about_panel.dart';
import 'package:anoworld/settings/ai_preset_page.dart';
import 'package:anoworld/settings/ai_settings_panel.dart';
import 'package:anoworld/settings/appearance_settings_panel.dart';
import 'package:anoworld/settings/general_settings_panel.dart';
import 'package:anoworld/settings/generation_settings_panel.dart';
import 'package:anoworld/settings/settings_display_labels.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/widgets.dart';

/// The page a settings entry opens.
///
/// Sections with a whole page of their own (library, preset) return it as is;
/// the rest are panels wrapped by [SettingsSectionView]. [key] identifies the
/// selection for the detail column, so switching entries remounts the pane.
Widget settingsSectionPage(SettingsSection section, {Key? key}) {
  return switch (section) {
    SettingsSection.plotElements => PlotElementsLibraryPage(key: key),
    SettingsSection.preset => AiPresetPage(key: key),
    _ => SettingsSectionView(key: key, section: section),
  };
}

/// One panel-backed settings section as a page of its own (no section rail).
///
/// The settings tab lists the sections flat and opens them here: pushed on
/// narrow windows, hosted in the detail column on wide ones.
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
    SettingsSection.generation => const GenerationSettingsPanel(),
    SettingsSection.about => const AboutPanel(),
    SettingsSection.plotElements || SettingsSection.preset => throw StateError(
      'Section $section is served by settingsSectionPage().',
    ),
  };
}
