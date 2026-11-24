import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/settings/vn_ui_settings.dart';
import 'package:anoworld/foundation/theme/app_dialogue_chrome.dart';
import 'package:anoworld/foundation/theme/app_hex_color.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_color_picker.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Visual-novel reading prefs (the stage dialogue box).
///
/// Opened from the play control bar; applies to every VN session.
class VnSettingsPage extends StatelessWidget {
  const VnSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final strings = context.strings;
    return AppPage(
      title: strings.vnSettingsTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final vnUi = VnUiSettings.resolved(controller.vnUi);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.pagePadding),
            children: [
              AppSectionHeader(strings.dialogueBoxSection, gutter: true),
              AppPageGutter(
                child: AppText(
                  strings.dialogueBoxHint,
                  role: AppTextRole.caption,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppSlider(
                label: strings.dialogueLines,
                icon: Icons.format_align_left,
                value: vnUi.lines.toDouble(),
                min: AppDialogueChrome.minLines.toDouble(),
                max: AppDialogueChrome.maxLines.toDouble(),
                step: 1,
                valueText: (v) => strings.dialogueLinesValue(v.round()),
                onChanged: (value) =>
                    controller.updateVnUi(vnUi.copyWith(lines: value.round())),
              ),
              AppSlider(
                label: strings.dialogueFontSize,
                icon: Icons.format_size,
                value: vnUi.fontSize,
                min: AppDialogueChrome.minFontSize,
                max: AppDialogueChrome.maxFontSize,
                step: AppDialogueChrome.fontSizeStep,
                valueText: strings.dialogueFontSizeValue,
                onChanged: (value) =>
                    controller.updateVnUi(vnUi.copyWith(fontSize: value)),
              ),
              AppSlider(
                label: strings.dialogueInnerInset,
                subtitle: strings.dialogueInnerInsetHint,
                icon: Icons.format_indent_increase,
                value: vnUi.innerInsetRatio,
                min: AppDialogueChrome.minInsetRatio,
                max: AppDialogueChrome.maxInsetRatio,
                step: AppDialogueChrome.insetRatioStep,
                valueText: strings.dialogueInsetRatioValue,
                onChanged: (value) => controller.updateVnUi(
                  vnUi.copyWith(innerInsetRatio: value),
                ),
              ),
              AppSlider(
                label: strings.dialogueOuterInset,
                subtitle: strings.dialogueOuterInsetHint,
                icon: Icons.crop_free,
                value: vnUi.outerInsetRatio,
                min: AppDialogueChrome.minInsetRatio,
                max: AppDialogueChrome.maxInsetRatio,
                step: AppDialogueChrome.insetRatioStep,
                valueText: strings.dialogueInsetRatioValue,
                onChanged: (value) => controller.updateVnUi(
                  vnUi.copyWith(outerInsetRatio: value),
                ),
              ),
              AppSlider(
                label: strings.dialogueControlSize,
                subtitle: strings.dialogueControlSizeHint,
                icon: Icons.radio_button_checked,
                value: vnUi.controlSizeRatio,
                min: AppDialogueChrome.minControlSizeRatio,
                max: AppDialogueChrome.maxControlSizeRatio,
                step: AppDialogueChrome.controlSizeRatioStep,
                valueText: strings.dialogueInsetRatioValue,
                onChanged: (value) => controller.updateVnUi(
                  vnUi.copyWith(controlSizeRatio: value),
                ),
              ),
              AppSlider(
                label: strings.dialogueControlTopGap,
                subtitle: strings.dialogueControlTopGapHint,
                icon: Icons.expand_less,
                value: vnUi.controlTopGapRatio,
                min: AppDialogueChrome.minControlVerticalGapRatio,
                max: AppDialogueChrome.maxControlVerticalGapRatio,
                step: AppDialogueChrome.controlVerticalGapRatioStep,
                valueText: strings.dialogueInsetRatioValue,
                onChanged: (value) => controller.updateVnUi(
                  vnUi.copyWith(controlTopGapRatio: value),
                ),
              ),
              AppSlider(
                label: strings.dialogueControlBottomGap,
                subtitle: strings.dialogueControlBottomGapHint,
                icon: Icons.expand_more,
                value: vnUi.controlBottomGapRatio,
                min: AppDialogueChrome.minControlVerticalGapRatio,
                max: AppDialogueChrome.maxControlVerticalGapRatio,
                step: AppDialogueChrome.controlVerticalGapRatioStep,
                valueText: strings.dialogueInsetRatioValue,
                onChanged: (value) => controller.updateVnUi(
                  vnUi.copyWith(controlBottomGapRatio: value),
                ),
              ),
              AppSlider(
                label: strings.dialogueTextSpeed,
                icon: Icons.speed_outlined,
                value: vnUi.textSpeed,
                min: AppDialogueChrome.minTextSpeed,
                max: AppDialogueChrome.maxTextSpeed,
                step: AppDialogueChrome.textSpeedStep,
                valueText: (v) => strings.dialogueTextSpeedValue(v.round()),
                onChanged: (value) =>
                    controller.updateVnUi(vnUi.copyWith(textSpeed: value)),
              ),
              AppSlider(
                label: strings.dialogueOpacity,
                icon: Icons.opacity,
                value: vnUi.opacity,
                min: AppDialogueChrome.minOpacity,
                max: AppDialogueChrome.maxOpacity,
                step: AppDialogueChrome.opacityStep,
                valueText: (v) =>
                    strings.dialogueOpacityValue((v * 100).round()),
                showDivider: false,
                onChanged: (value) =>
                    controller.updateVnUi(vnUi.copyWith(opacity: value)),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              AppSectionHeader(strings.dialogueColorsSection, gutter: true),
              AppListTile(
                title: strings.dialogueBackground,
                subtitle: vnUi.followsTheme
                    ? strings.dialogueFollowTheme
                    : vnUi.backgroundHex,
                icon: Icons.palette_outlined,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ColorSwatch(
                      color: AppDialogueChrome.fill(
                        context,
                        backgroundHex: vnUi.backgroundHex,
                        opacity: vnUi.opacity,
                      ),
                    ),
                    const AppForwardIcon(),
                  ],
                ),
                onTap: () => _pickColor(
                  context,
                  initialHex: vnUi.backgroundHex,
                  fallback:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  title: strings.dialogueBackground,
                  apply: (hex) =>
                      controller.updateVnUi(vnUi.copyWith(backgroundHex: hex)),
                ),
              ),
              AppListTile(
                title: strings.dialogueBackgroundTheme,
                subtitle: strings.dialogueBackgroundThemeHint,
                icon: Icons.format_color_reset_outlined,
                trailing: AppSwitch(
                  value: vnUi.followsTheme,
                  onChanged: (on) => controller.updateVnUi(
                    vnUi.copyWith(backgroundHex: on ? '' : _themeHex(context)),
                  ),
                ),
                onTap: () => controller.updateVnUi(
                  vnUi.copyWith(
                    backgroundHex: vnUi.followsTheme ? _themeHex(context) : '',
                  ),
                ),
              ),
              AppListTile(
                title: strings.dialogueText,
                subtitle: vnUi.textFollowsTheme
                    ? strings.dialogueFollowTheme
                    : vnUi.textHex,
                icon: Icons.format_color_text,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ColorSwatch(
                      color:
                          tryParseHexColor(vnUi.textHex) ??
                          _themeTextColor(context),
                    ),
                    const AppForwardIcon(),
                  ],
                ),
                onTap: () => _pickColor(
                  context,
                  initialHex: vnUi.textHex,
                  fallback: _themeTextColor(context),
                  title: strings.dialogueText,
                  apply: (hex) =>
                      controller.updateVnUi(vnUi.copyWith(textHex: hex)),
                ),
              ),
              AppListTile(
                title: strings.dialogueTextTheme,
                subtitle: strings.dialogueTextThemeHint,
                icon: Icons.format_color_reset_outlined,
                trailing: AppSwitch(
                  value: vnUi.textFollowsTheme,
                  onChanged: (on) => controller.updateVnUi(
                    vnUi.copyWith(
                      textHex: on ? '' : hexFromColor(_themeTextColor(context)),
                    ),
                  ),
                ),
                onTap: () => controller.updateVnUi(
                  vnUi.copyWith(
                    textHex: vnUi.textFollowsTheme
                        ? hexFromColor(_themeTextColor(context))
                        : '',
                  ),
                ),
                showDivider: false,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _themeHex(BuildContext context) =>
      hexFromColor(Theme.of(context).colorScheme.surfaceContainerHighest);

  static Color _themeTextColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
  }

  Future<void> _pickColor(
    BuildContext context, {
    required String initialHex,
    required Color fallback,
    required String title,
    required Future<void> Function(String hex) apply,
  }) async {
    final picked = await showAppColorPicker(
      context,
      initialColor: tryParseHexColor(initialHex) ?? fallback,
      title: title,
    );
    if (picked == null) return;
    await apply(hexFromColor(picked));
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
