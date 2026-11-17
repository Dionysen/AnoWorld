import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Chat-only prefs (composer gear). Not the global settings shell.
class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return AppPage(
      title: '聊天设置',
      onBack: () => Navigator.of(context).maybePop(),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final chatUi = controller.chatUi;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.pagePadding),
            children: [
              const AppSectionHeader('阅读', gutter: true),
              const AppPageGutter(
                child: AppText(
                  '只影响聊天气泡里的正文',
                  role: AppTextRole.caption,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppSlider(
                label: '行距',
                icon: Icons.format_line_spacing,
                value: chatUi.lineHeight,
                min: AppChatChrome.minLineHeight,
                max: AppChatChrome.maxLineHeight,
                step: AppChatChrome.lineHeightStep,
                valueText: (v) => '${v.toStringAsFixed(2)} ×',
                onChanged: (value) {
                  controller.updateChatUi(
                    chatUi.copyWith(lineHeight: value),
                  );
                },
              ),
              AppSlider(
                label: '段间距',
                icon: Icons.vertical_distribute,
                value: chatUi.paragraphSpacing,
                min: AppChatChrome.minParagraphSpacing,
                max: AppChatChrome.maxParagraphSpacing,
                step: AppChatChrome.paragraphSpacingStep,
                valueText: (v) => '${v.round()} px',
                showDivider: false,
                onChanged: (value) {
                  controller.updateChatUi(
                    chatUi.copyWith(paragraphSpacing: value),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
