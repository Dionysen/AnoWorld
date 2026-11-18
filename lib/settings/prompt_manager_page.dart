import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/settings/prompt_manager_panel.dart';
import 'package:flutter/material.dart';

/// Full-page prompt manager (legacy route; preset tab embeds [PromptManagerPanel]).
class PromptManagerPage extends StatelessWidget {
  const PromptManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '提示词分段',
      onBack: () => Navigator.of(context).maybePop(),
      body: const AppPageBody.list(
        children: [
          AppSectionHeader(
            '顺序与开关',
            subtitle: '写故事时按序拼进系统提示',
            gutter: true,
          ),
          PromptManagerPanel(),
        ],
      ),
    );
  }
}