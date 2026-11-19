import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/ai_preset_panel.dart';
import 'package:flutter/widgets.dart';

/// Preset picker, sampling and prompt sections, entered from the play tab.
class AiPresetPage extends StatelessWidget {
  const AiPresetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: context.strings.aiPresetTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: const AppPageBody.list(children: [AiPresetPanel()]),
    );
  }
}
