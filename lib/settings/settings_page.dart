import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:flutter/widgets.dart';

/// Settings shell. AI API fields land here in a later slice.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '设置',
      onBack: () => Navigator.of(context).maybePop(),
      body: const AppPageBody(
        children: [
          AppSectionHeader('文本与生图'),
          AppEmptyState(
            message: 'API 配置稍后接入',
            detail: '这里会放文本 AI 与生图的地址、密钥和模型。',
          ),
        ],
      ),
    );
  }
}
