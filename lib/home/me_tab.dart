import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/persona_settings_panel.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:flutter/material.dart';

/// Profile tab: player personas (酒馆式「我是谁」).
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  Future<void> _openSettings(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const SettingsPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageBody.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            AppTheme.spaceXs,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: AppIconButton(
              icon: Icons.settings_outlined,
              tooltip: '设置',
              onPressed: () => _openSettings(context),
            ),
          ),
        ),
        const PersonaSettingsPanel(),
      ],
    );
  }
}
