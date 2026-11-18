import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/persona_settings_panel.dart';
import 'package:flutter/material.dart';

/// Profile tab: player personas (酒馆式「我是谁」).
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageBody.list(
      children: [PersonaSettingsPanel()],
    );
  }
}