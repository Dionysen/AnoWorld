import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
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
    final strings = context.strings;
    return AppPage(
      title: strings.chatSettingsTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final chatUi = controller.chatUi;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.pagePadding),
            children: [
              AppSectionHeader(strings.readingSection, gutter: true),
              AppPageGutter(
                child: AppText(
                  strings.readingSectionHint,
                  role: AppTextRole.caption,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppSlider(
                label: strings.lineHeight,
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
                label: strings.paragraphSpacing,
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
              AppSectionHeader(strings.bubblesSection, gutter: true),
              AppSlider(
                label: strings.bubbleRadius,
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
                title: strings.showReasoning,
                subtitle: strings.showReasoningHint,
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
              AppSectionHeader(strings.avatarsSection, gutter: true),
              AppListTile(
                title: strings.characterAvatar,
                subtitle: strings.characterAvatarHint,
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
                title: strings.myAvatar,
                subtitle: strings.myAvatarHint,
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
                title: strings.avatarAboveBubble,
                subtitle: strings.avatarAboveBubbleHint,
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
              AppSectionHeader(strings.backgroundSection, gutter: true),
              AppListTile(
                title: strings.chatBackground,
                subtitle: _backgroundSubtitle(context, chatUi.background),
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

  static String _backgroundSubtitle(
    BuildContext context,
    AppChatBackground background,
  ) {
    return switch (background.kind) {
      AppChatBackgroundKind.none => context.strings.backgroundThemeDefault,
      AppChatBackgroundKind.color => context.strings.backgroundSolid,
      AppChatBackgroundKind.gradient => context.strings.backgroundGradient,
    };
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
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.spaceSm,
        AppTheme.pagePadding,
        AppTheme.pagePadding,
      ),
      children: [
        AppText(strings.chatBackground, role: AppTextRole.subtitle),
        const SizedBox(height: AppTheme.spaceXs),
        AppText(strings.backgroundPickerHint, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceMd),
        AppListTile(
          title: strings.backgroundThemeDefault,
          subtitle: strings.backgroundThemeDefaultHint,
          icon: Icons.palette_outlined,
          selected: current.kind == AppChatBackgroundKind.none,
          trailing: current.kind == AppChatBackgroundKind.none
              ? Icon(Icons.check, color: scheme.primary, size: 20)
              : null,
          onTap: () => onSelect(AppChatBackground.none),
          showDivider: false,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        AppText(strings.gradientSection, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceSm),
        _PresetGrid(
          items: AppChatBackground.gradientPresets,
          current: current,
          onSelect: onSelect,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        AppText(strings.backgroundSolid, role: AppTextRole.caption),
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
