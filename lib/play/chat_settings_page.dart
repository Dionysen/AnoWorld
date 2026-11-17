import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/foundation/theme/app_chat_background.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
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
              const SizedBox(height: AppTheme.spaceMd),
              const AppSectionHeader('气泡', gutter: true),
              AppSlider(
                label: '气泡圆角',
                icon: Icons.rounded_corner,
                value: chatUi.bubbleCornerRadius,
                min: AppChatChrome.minBubbleCornerRadius,
                max: AppChatChrome.maxBubbleCornerRadius,
                step: AppChatChrome.bubbleCornerRadiusStep,
                valueText: (v) => '${v.round()}',
                onChanged: (value) {
                  controller.updateChatUi(
                    chatUi.copyWith(bubbleCornerRadius: value),
                  );
                },
              ),
              AppListTile(
                title: '显示思考过程',
                subtitle: '模型有思考内容时，折叠在气泡上方',
                icon: Icons.psychology_outlined,
                trailing: AppSwitch(
                  value: chatUi.showReasoning,
                  onChanged: (on) {
                    controller.updateChatUi(
                      chatUi.copyWith(showReasoning: on),
                    );
                  },
                ),
                onTap: () {
                  controller.updateChatUi(
                    chatUi.copyWith(showReasoning: !chatUi.showReasoning),
                  );
                },
                showDivider: false,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              const AppSectionHeader('头像', gutter: true),
              AppListTile(
                title: '角色头像',
                subtitle: '助手气泡旁显示',
                icon: Icons.face_outlined,
                trailing: AppSwitch(
                  value: chatUi.showCharacterAvatar,
                  onChanged: (on) {
                    controller.updateChatUi(
                      chatUi.copyWith(showCharacterAvatar: on),
                    );
                  },
                ),
                onTap: () {
                  controller.updateChatUi(
                    chatUi.copyWith(
                      showCharacterAvatar: !chatUi.showCharacterAvatar,
                    ),
                  );
                },
              ),
              AppListTile(
                title: '我的头像',
                subtitle: '自己气泡旁显示',
                icon: Icons.person_outline,
                trailing: AppSwitch(
                  value: chatUi.showUserAvatar,
                  onChanged: (on) {
                    controller.updateChatUi(
                      chatUi.copyWith(showUserAvatar: on),
                    );
                  },
                ),
                onTap: () {
                  controller.updateChatUi(
                    chatUi.copyWith(showUserAvatar: !chatUi.showUserAvatar),
                  );
                },
              ),
              AppListTile(
                title: '头像在气泡上方',
                subtitle: '关闭后头像与气泡并排',
                icon: Icons.vertical_align_top,
                trailing: AppSwitch(
                  value: chatUi.avatarAboveBubble,
                  onChanged: (on) {
                    controller.updateChatUi(
                      chatUi.copyWith(avatarAboveBubble: on),
                    );
                  },
                ),
                onTap: () {
                  controller.updateChatUi(
                    chatUi.copyWith(
                      avatarAboveBubble: !chatUi.avatarAboveBubble,
                    ),
                  );
                },
                showDivider: false,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              const AppSectionHeader('背景', gutter: true),
              AppListTile(
                title: '聊天背景',
                subtitle: _backgroundSubtitle(chatUi.background),
                icon: Icons.wallpaper_outlined,
                trailing: const AppForwardIcon(),
                onTap: () => _pickBackground(context, chatUi),
                showDivider: false,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _backgroundSubtitle(AppChatBackground background) {
    switch (background.kind) {
      case AppChatBackgroundKind.none:
        return '主题默认';
      case AppChatBackgroundKind.color:
        return '纯色';
      case AppChatBackgroundKind.gradient:
        return '内置渐变';
    }
  }

  Future<void> _pickBackground(
    BuildContext context,
    ChatUiSettings chatUi,
  ) async {
    final controller = AppScope.settingsOf(context);
    final selected = await showAppSheet<AppChatBackground>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) {
        return _ChatBackgroundPicker(
          current: chatUi.background,
          onSelect: (bg) => Navigator.of(sheetContext).pop(bg),
        );
      },
    );
    if (selected == null) return;
    await controller.updateChatUi(chatUi.copyWith(background: selected));
  }
}

class _ChatBackgroundPicker extends StatelessWidget {
  const _ChatBackgroundPicker({
    required this.current,
    required this.onSelect,
  });

  final AppChatBackground current;
  final ValueChanged<AppChatBackground> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.spaceSm,
        AppTheme.pagePadding,
        AppTheme.pagePadding,
      ),
      children: [
        const AppText('聊天背景', role: AppTextRole.subtitle),
        const SizedBox(height: AppTheme.spaceXs),
        const AppText('选一块铺在主题底色上', role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceMd),
        AppListTile(
          title: '主题默认',
          subtitle: '跟当前主题的聊天底色',
          icon: Icons.palette_outlined,
          selected: current.kind == AppChatBackgroundKind.none,
          trailing: current.kind == AppChatBackgroundKind.none
              ? Icon(Icons.check, color: scheme.primary, size: 20)
              : null,
          onTap: () => onSelect(AppChatBackground.none),
          showDivider: false,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        const AppText('渐变', role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceSm),
        _PresetGrid(
          items: AppChatBackground.gradientPresets,
          current: current,
          onSelect: onSelect,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        const AppText('纯色', role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceSm),
        _PresetGrid(
          items: AppChatBackground.solidPresets,
          current: current,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({
    required this.items,
    required this.current,
    required this.onSelect,
  });

  final List<AppChatBackground> items;
  final AppChatBackground current;
  final ValueChanged<AppChatBackground> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppTheme.spaceSm,
        crossAxisSpacing: AppTheme.spaceSm,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final bg = items[index];
        final selected = current.matches(bg);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(bg),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
                gradient: bg.kind == AppChatBackgroundKind.gradient
                    ? bg.toGradient()
                    : null,
                color: bg.kind == AppChatBackgroundKind.color
                    ? AppChatBackground.parseHex(bg.colorHex)
                    : null,
              ),
              child: selected
                  ? Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: scheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
