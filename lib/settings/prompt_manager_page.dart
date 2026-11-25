import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/settings/prompt_manager_panel.dart';
import 'package:flutter/material.dart';

/// Full-page prompt manager (legacy route; preset tab embeds [PromptManagerPanel]).
class PromptManagerPage extends StatelessWidget {
  const PromptManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: context.strings.promptSectionsTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: const PromptManagerPanel(),
    );
  }
}
