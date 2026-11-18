import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/persona_settings_panel.dart';
import 'package:flutter/material.dart';

class PersonaSettingsPage extends StatelessWidget {
  const PersonaSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '玩家身份',
      onBack: () => Navigator.of(context).maybePop(),
      body: const AppPageBody.list(children: [PersonaSettingsPanel()]),
    );
  }
}