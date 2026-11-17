import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/settings_section_view.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/widgets.dart';

/// Settings opened from the home title action.
///
/// Portrait: bottom nav for 通用 / 外观 / 预设 / AI / 关于.
/// Landscape: left rail for the same sections.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.initialSection = SettingsSection.general,
  });

  final SettingsSection initialSection;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsSection _section = widget.initialSection;

  int get _index => SettingsSection.values.indexOf(_section);

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '设置',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppNavShell(
        destinations: settingsNavItems,
        selectedIndex: _index < 0 ? 0 : _index,
        onDestinationSelected: (index) {
          setState(() => _section = SettingsSection.values[index]);
        },
        // Nested under AppPage title band — do not pad for chrome again.
        railTopInset: 0,
        body: SettingsSectionBody(section: _section),
      ),
    );
  }
}
