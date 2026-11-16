import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/settings/about_panel.dart';
import 'package:anoworld/settings/ai_settings_panel.dart';
import 'package:anoworld/settings/appearance_settings_panel.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/widgets.dart';

/// Scrollable body for one settings section (no page chrome).
class SettingsSectionBody extends StatelessWidget {
  const SettingsSectionBody({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return AppPageBody(children: [_bodyFor(section)]);
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
      title: section.label,
      onBack: onBack,
      body: AppPageBody(
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
    SettingsSection.general => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader('通用'),
          AppEmptyState(
            message: '通用选项稍后接入',
            detail: '语言、启动行为等开关会放在这里。外观请到「外观」分区。',
          ),
        ],
      ),
    SettingsSection.appearance => const AppearanceSettingsPanel(),
    SettingsSection.ai => const AiSettingsPanel(),
    SettingsSection.about => const AboutPanel(),
  };
}
