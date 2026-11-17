import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/ai_preset_panel.dart';
import 'package:flutter/material.dart';

class AiPresetsSettingsPage extends StatelessWidget {
  const AiPresetsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'AI 预设',
      onBack: () => Navigator.of(context).maybePop(),
      body: const AppPageBody(
        children: [AiPresetPanel()],
      ),
    );
  }
}