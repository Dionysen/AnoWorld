import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/widgets.dart';

/// Scrollable body for one settings section (no page chrome).
class SettingsSectionBody extends StatelessWidget {
  const SettingsSectionBody({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return AppPageBody(children: _bodyFor(section));
  }
}

/// Standalone page wrapper when a section is opened without the settings shell.
class SettingsSectionView extends StatelessWidget {
  const SettingsSectionView({
    super.key,
    required this.section,
    this.onBack,
    this.header,
  });

  final SettingsSection section;
  final VoidCallback? onBack;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: section.label,
      onBack: onBack,
      body: AppPageBody(
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: AppTheme.spaceMd),
          ],
          ..._bodyFor(section),
        ],
      ),
    );
  }
}

List<Widget> _bodyFor(SettingsSection section) {
  return switch (section) {
    SettingsSection.general => const [
        AppSectionHeader('通用'),
        AppEmptyState(
          message: '通用选项稍后接入',
          detail: '语言、启动行为、窗口与外观相关开关会放在这里。',
        ),
      ],
    SettingsSection.ai => const [
        AppSectionHeader('文本与生图'),
        AppEmptyState(
          message: 'API 配置稍后接入',
          detail: '这里会放文本 AI 与生图的地址、密钥和模型。',
        ),
      ],
    SettingsSection.about => const [
        AppSectionHeader('关于'),
        AppText('AnoWorld', role: AppTextRole.subtitle),
        SizedBox(height: AppTheme.spaceSm),
        AppText(
          '视觉小说创作器与运行时。本地作品包，双模式游玩。',
          role: AppTextRole.body,
        ),
        SizedBox(height: AppTheme.spaceMd),
        AppText('版本 0.1.0', role: AppTextRole.caption),
      ],
  };
}
