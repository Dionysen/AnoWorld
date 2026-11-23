import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/app/settings_controller.dart';
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
          final vnUi = controller.vnUi;
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
              AppSectionHeader(strings.dialogueBackground, gutter: true),
              AppListTile(
                title: strings.dialogueBackground,
                subtitle: vnUi.followsTheme
                    ? strings.dialogueBackgroundTheme
                    : vnUi.backgroundHex,
                icon: Icons.palette_outlined,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ColorSwatch(settings: vnUi),
                    const AppForwardIcon(),
                  ],
                ),
                onTap: () => _pickColor(context, controller, vnUi),
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

  Future<void> _pickColor(
    BuildContext context,
    SettingsController controller,
    VnUiSettings vnUi,
  ) async {
    final picked = await showAppColorPicker(
      context,
      initialColor:
          tryParseHexColor(vnUi.backgroundHex) ??
          Theme.of(context).colorScheme.surfaceContainerHighest,
      title: context.strings.dialogueBackground,
    );
    if (picked == null) return;
    await controller.updateVnUi(
      vnUi.copyWith(backgroundHex: hexFromColor(picked)),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.settings});

  final VnUiSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill =
        tryParseHexColor(settings.backgroundHex) ??
        scheme.surfaceContainerHighest;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: fill.withValues(alpha: settings.opacity),
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outline),
      ),
    );
  }
}
