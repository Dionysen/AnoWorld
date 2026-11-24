import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_slider.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Generation preferences: image output and visual-novel direction.
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

  Future<void> _openInStationChoiceSheet(AiSettings ai) async {
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.compact,
      builder: (sheetContext) {
        final strings = context.strings;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                AppTheme.spaceSm,
              ),
              child: AppSectionHeader(strings.vnInStationChoicesLabel),
            ),
            for (final freq in InStationChoiceFrequency.values)
              AppListTile(
                title: strings.vnInStationChoiceFrequencyName(freq),
                selected: freq == ai.inStationChoiceFrequency,
                trailing: freq == ai.inStationChoiceFrequency
                    ? AppText(
                        strings.currentTag,
                        role: AppTextRole.caption,
                      )
                    : null,
                onTap: () async {
                  await _persist(ai.copyWith(inStationChoiceFrequency: freq));
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
              ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
        );
      },
    );
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

  List<Widget> _sizeSection({
    required AppStrings strings,
    required String title,
    required String hint,
    required int width,
    required int height,
    required List<ImageGenSizePreset> presets,
    required ValueChanged<ImageGenSizePreset> onPreset,
    required ValueChanged<int> onWidth,
    required ValueChanged<int> onHeight,
  }) {
    return [
      AppSectionHeader(title, gutter: true),
      AppPageGutter(
        child: AppText(hint, role: AppTextRole.caption),
      ),
      const SizedBox(height: AppTheme.spaceSm),
      AppListTile(
        title: strings.imageGenSizePresetLabel,
        subtitle: strings.imageGenSizeValue(width, height),
        icon: Icons.aspect_ratio_outlined,
        trailing: const AppForwardIcon(),
        onTap: () async {
          final picked = await _pickSizePreset(
            presets: presets,
            currentWidth: width,
            currentHeight: height,
          );
          if (picked == null || !mounted) return;
          onPreset(picked);
        },
      ),
      AppSlider(
        label: strings.imageGenWidthLabel,
        subtitle: strings.imageGenWidthHint,
        icon: Icons.swap_horiz_outlined,
        value: width.toDouble(),
        min: AiImageEndpoint.sizeLowerBound.toDouble(),
        max: AiImageEndpoint.sizeUpperBound.toDouble(),
        step: AiImageEndpoint.sizeStep.toDouble(),
        valueText: (v) => '${v.round()}',
        onChanged: (value) => onWidth(value.round()),
      ),
      AppSlider(
        label: strings.imageGenHeightLabel,
        subtitle: strings.imageGenHeightHint,
        icon: Icons.swap_vert_outlined,
        value: height.toDouble(),
        min: AiImageEndpoint.sizeLowerBound.toDouble(),
        max: AiImageEndpoint.sizeUpperBound.toDouble(),
        step: AiImageEndpoint.sizeStep.toDouble(),
        valueText: (v) => '${v.round()}',
        showDivider: false,
        onChanged: (value) => onHeight(value.round()),
      ),
    ];
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
              subtitle: strings.imageGenStepsHint,
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
            ..._sizeSection(
              strings: strings,
              title: strings.imageGenPortraitSizeLabel,
              hint: strings.imageGenPortraitSizeHint,
              width: ai.image.portraitWidth,
              height: ai.image.portraitHeight,
              presets: ImageGenSizePresets.portrait,
              onPreset: (picked) => _persist(
                ai.withImage(
                  ai.image.copyWith(
                    portraitWidth: picked.width,
                    portraitHeight: picked.height,
                  ),
                ),
              ),
              onWidth: (w) => _persist(
                ai.withImage(ai.image.copyWith(portraitWidth: w)),
              ),
              onHeight: (h) => _persist(
                ai.withImage(ai.image.copyWith(portraitHeight: h)),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ..._sizeSection(
              strings: strings,
              title: strings.imageGenSceneSizeLabel,
              hint: strings.imageGenSceneSizeHint,
              width: ai.image.sceneWidth,
              height: ai.image.sceneHeight,
              presets: ImageGenSizePresets.scene,
              onPreset: (picked) => _persist(
                ai.withImage(
                  ai.image.copyWith(
                    sceneWidth: picked.width,
                    sceneHeight: picked.height,
                  ),
                ),
              ),
              onWidth: (w) => _persist(
                ai.withImage(ai.image.copyWith(sceneWidth: w)),
              ),
              onHeight: (h) => _persist(
                ai.withImage(ai.image.copyWith(sceneHeight: h)),
              ),
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
              subtitle: strings.vnMinLinesHint,
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
              subtitle: strings.minGraphStationsHint,
              icon: Icons.account_tree_outlined,
              value: ai.minGraphStations.toDouble(),
              min: AiSettings.minGraphStationsLowerBound.toDouble(),
              max: AiSettings.minGraphStationsUpperBound.toDouble(),
              step: 1,
              valueText: (v) => strings.minGraphStationsValue(v.round()),
              onChanged: (value) =>
                  _persist(ai.copyWith(minGraphStations: value.round())),
            ),
            AppListTile(
              title: strings.vnInStationChoicesLabel,
              subtitle: strings.vnInStationChoicesHint,
              icon: Icons.alt_route_outlined,
              showDivider: false,
              onTap: () => _openInStationChoiceSheet(ai),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: AppText(
                  strings.vnInStationChoiceFrequencyName(
                    ai.inStationChoiceFrequency,
                  ),
                  role: AppTextRole.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
