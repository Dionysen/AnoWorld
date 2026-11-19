import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/about_panel.dart';
import 'package:anoworld/settings/ai_settings_panel.dart';
import 'package:anoworld/settings/appearance_settings_panel.dart';
import 'package:anoworld/settings/general_settings_panel.dart';
import 'package:anoworld/settings/settings_display_labels.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/widgets.dart';

/// Scrollable body for one settings section (no page chrome).
class SettingsSectionBody extends StatelessWidget {
  const SettingsSectionBody({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    // Vertical pad only so flat list rows can span the content width.
    return AppPageBody.list(children: [_bodyFor(section)]);
  }
}

/// Standalone page wrapper when a section is opened without the settings shell.
class SettingsSectionView extends StatelessWidget {
  const SettingsSectionView({
    super.key,
    required this.section,
    this.onBack,
    this.header,
  });

  final SettingsSection section;
  final VoidCallback? onBack;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: settingsSectionLabel(context.strings, section),
      onBack: onBack,
      body: AppPageBody.list(
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: AppTheme.spaceMd),
          ],
          _bodyFor(section),
        ],
      ),
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
