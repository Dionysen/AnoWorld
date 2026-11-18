import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/me_user_header.dart';
import 'package:anoworld/settings/persona_settings_page.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:flutter/material.dart';

/// Profile tab: current player identity + entry to manage identities / settings.
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

  Future<void> _openPersonaHub(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PersonaSettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
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
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final persona = controller.activePersona;
            if (persona == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
                child: AppText('还没有身份', role: AppTextRole.caption),
              );
            }
            return MeUserHeader(
              persona: persona,
              onTap: () => _openPersonaHub(context),
            );
          },
        ),
      ],
    );
  }
}
