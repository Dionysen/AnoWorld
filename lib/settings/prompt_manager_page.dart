import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/settings/prompt_manager_panel.dart';
import 'package:flutter/material.dart';

/// Full-page prompt manager (legacy route; preset tab embeds [PromptManagerPanel]).
class PromptManagerPage extends StatelessWidget {
  const PromptManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppPage(
      title: strings.promptSectionsTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          AppSectionHeader(
            strings.promptOrderSection,
            subtitle: strings.promptOrderHint,
            gutter: true,
          ),
          const PromptManagerPanel(),
        ],
      ),
    );
  }
}
