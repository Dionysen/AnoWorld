import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Generation preferences: image quality and visual-novel direction.
///
/// API endpoints stay on [AiSettingsPanel]; sampling for presets lives under
/// the play-modes preset page.
class GenerationSettingsPanel extends StatefulWidget {
  const GenerationSettingsPanel({super.key});

  @override
  State<GenerationSettingsPanel> createState() =>
      _GenerationSettingsPanelState();
}

class _GenerationSettingsPanelState extends State<GenerationSettingsPanel> {
  Future<void> _persist(AiSettings next) async {
    await AppScope.settingsOf(context).updateAi(next);
  }

  Future<ImageGenSizePreset?> _pickSizePreset({
    required List<ImageGenSizePreset> presets,
    required int currentWidth,
    required int currentHeight,
  }) {
    return showAppSheet<ImageGenSizePreset>(
      context: context,
      size: AppSheetSize.half,
      builder: (context) {
        final strings = context.strings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                0,
              ),
              child: AppSectionHeader(strings.imageGenSizePresetLabel),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  0,
                  0,
                  AppTheme.spaceMd,
                ),
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  final selected = preset.width == currentWidth &&
                      preset.height == currentHeight;
                  return AppListTile(
                    title: strings.imageGenSizePresetValue(preset),
                    subtitle: preset.aspectLabel,
                    icon: Icons.crop_outlined,
                    onTap: () => Navigator.of(context).pop(preset),
                    trailing: selected
                        ? AppText(
                            strings.currentTag,
                            role: AppTextRole.caption,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ai = controller.ai;
        final strings = context.strings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              strings.imageGenQualitySection,
              gutter: true,
            ),
            AppPageGutter(
              child: AppText(
                strings.imageGenQualityHint,
                role: AppTextRole.caption,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppSlider(
              label: strings.imageGenStepsLabel,
              icon: Icons.tune_outlined,
              value: ai.image.steps.toDouble(),
              min: AiImageEndpoint.stepsLowerBound.toDouble(),
              max: AiImageEndpoint.stepsUpperBound.toDouble(),
              step: 1,
              valueText: (v) => strings.imageGenStepsValue(v.round()),
              onChanged: (value) => _persist(
                ai.withImage(ai.image.copyWith(steps: value.round())),
              ),
            ),
            AppPageGutter(
              child: AppText(
                strings.imageGenPortraitSizeLabel,
                role: AppTextRole.label,
              ),
            ),
            AppListTile(
              title: strings.imageGenSizePresetLabel,
              subtitle: strings.imageGenSizeValue(
                ai.image.portraitWidth,
                ai.image.portraitHeight,
              ),
              icon: Icons.aspect_ratio_outlined,
              trailing: const AppForwardIcon(),
              onTap: () async {
                final picked = await _pickSizePreset(
                  presets: ImageGenSizePresets.portrait,
                  currentWidth: ai.image.portraitWidth,
                  currentHeight: ai.image.portraitHeight,
                );
                if (picked == null || !mounted) return;
                await _persist(
                  ai.withImage(
                    ai.image.copyWith(
                      portraitWidth: picked.width,
                      portraitHeight: picked.height,
                    ),
                  ),
                );
              },
            ),
            AppSlider(
              label: strings.imageGenWidthLabel,
              icon: Icons.swap_horiz_outlined,
              value: ai.image.portraitWidth.toDouble(),
              min: AiImageEndpoint.sizeLowerBound.toDouble(),
              max: AiImageEndpoint.sizeUpperBound.toDouble(),
              step: AiImageEndpoint.sizeStep.toDouble(),
              valueText: (v) => '${v.round()}',
              onChanged: (value) => _persist(
                ai.withImage(
                  ai.image.copyWith(portraitWidth: value.round()),
                ),
              ),
            ),
            AppSlider(
              label: strings.imageGenHeightLabel,
              icon: Icons.swap_vert_outlined,
              value: ai.image.portraitHeight.toDouble(),
              min: AiImageEndpoint.sizeLowerBound.toDouble(),
              max: AiImageEndpoint.sizeUpperBound.toDouble(),
              step: AiImageEndpoint.sizeStep.toDouble(),
              valueText: (v) => '${v.round()}',
              onChanged: (value) => _persist(
                ai.withImage(
                  ai.image.copyWith(portraitHeight: value.round()),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppPageGutter(
              child: AppText(
                strings.imageGenSceneSizeLabel,
                role: AppTextRole.label,
              ),
            ),
            AppListTile(
              title: strings.imageGenSizePresetLabel,
              subtitle: strings.imageGenSizeValue(
                ai.image.sceneWidth,
                ai.image.sceneHeight,
              ),
              icon: Icons.aspect_ratio_outlined,
              trailing: const AppForwardIcon(),
              onTap: () async {
                final picked = await _pickSizePreset(
                  presets: ImageGenSizePresets.scene,
                  currentWidth: ai.image.sceneWidth,
                  currentHeight: ai.image.sceneHeight,
                );
                if (picked == null || !mounted) return;
                await _persist(
                  ai.withImage(
                    ai.image.copyWith(
                      sceneWidth: picked.width,
                      sceneHeight: picked.height,
                    ),
                  ),
                );
              },
            ),
            AppSlider(
              label: strings.imageGenWidthLabel,
              icon: Icons.swap_horiz_outlined,
              value: ai.image.sceneWidth.toDouble(),
              min: AiImageEndpoint.sizeLowerBound.toDouble(),
              max: AiImageEndpoint.sizeUpperBound.toDouble(),
              step: AiImageEndpoint.sizeStep.toDouble(),
              valueText: (v) => '${v.round()}',
              onChanged: (value) => _persist(
                ai.withImage(ai.image.copyWith(sceneWidth: value.round())),
              ),
            ),
            AppSlider(
              label: strings.imageGenHeightLabel,
              icon: Icons.swap_vert_outlined,
              value: ai.image.sceneHeight.toDouble(),
              min: AiImageEndpoint.sizeLowerBound.toDouble(),
              max: AiImageEndpoint.sizeUpperBound.toDouble(),
              step: AiImageEndpoint.sizeStep.toDouble(),
              valueText: (v) => '${v.round()}',
              onChanged: (value) => _persist(
                ai.withImage(ai.image.copyWith(sceneHeight: value.round())),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppListTile(
              title: strings.imageGenUpscaleLabel,
              subtitle: strings.imageGenUpscaleHint,
              icon: Icons.high_quality_outlined,
              trailing: AppSwitch(
                value: ai.image.upscale,
                onChanged: (on) =>
                    _persist(ai.withImage(ai.image.copyWith(upscale: on))),
              ),
              onTap: () => _persist(
                ai.withImage(ai.image.copyWith(upscale: !ai.image.upscale)),
              ),
              showDivider: false,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(
              strings.vnDirectionSection,
              gutter: true,
            ),
            AppPageGutter(
              child: AppText(
                strings.vnDirectionHint,
                role: AppTextRole.caption,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppSlider(
              label: strings.vnMinLinesLabel,
              icon: Icons.movie_filter_outlined,
              value: ai.minBridgeLines.toDouble(),
              min: AiSettings.minBridgeLinesLowerBound.toDouble(),
              max: AiSettings.minBridgeLinesUpperBound.toDouble(),
              step: 1,
              valueText: (v) => strings.vnMinLinesValue(v.round()),
              onChanged: (value) =>
                  _persist(ai.copyWith(minBridgeLines: value.round())),
            ),
            AppSlider(
              label: strings.minGraphStationsLabel,
              icon: Icons.account_tree_outlined,
              value: ai.minGraphStations.toDouble(),
              min: AiSettings.minGraphStationsLowerBound.toDouble(),
              max: AiSettings.minGraphStationsUpperBound.toDouble(),
              step: 1,
              valueText: (v) => strings.minGraphStationsValue(v.round()),
              showDivider: false,
              onChanged: (value) =>
                  _persist(ai.copyWith(minGraphStations: value.round())),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppPageGutter(
              child: AppText(
                strings.vnInStationChoicesLabel,
                role: AppTextRole.label,
              ),
            ),
            AppPageGutter(
              child: AppText(
                strings.vnInStationChoicesHint,
                role: AppTextRole.caption,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppPageGutter(
              child: AppSegmented<InStationChoiceFrequency>(
                value: ai.inStationChoiceFrequency,
                options: [
                  for (final freq in InStationChoiceFrequency.values)
                    AppSegmentOption(
                      value: freq,
                      label: strings.vnInStationChoiceFrequencyName(freq),
                    ),
                ],
                onChanged: (freq) => _persist(
                  ai.copyWith(inStationChoiceFrequency: freq),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
