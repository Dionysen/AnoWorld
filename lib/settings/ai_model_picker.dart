import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/material.dart';

enum _ModelThinkingStep { model, effort }

/// Half-sheet list of model ids (settings「模型」行).
Future<String?> showAiModelSheet(
  BuildContext context, {
  required List<String> models,
  required String current,
}) {
  return showAppSheet<String>(
    context: context,
    size: AppSheetSize.half,
    builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceXs,
              AppTheme.pagePadding,
              AppTheme.spaceXs,
            ),
            child: AppSectionHeader(context.strings.chooseModel),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppTheme.spaceGroup,
                0,
                AppTheme.spaceMd,
              ),
              itemCount: models.length,
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final id = models[index];
                return AppListTile(
                  title: id,
                  icon: Icons.smart_toy_outlined,
                  onTap: () => Navigator.of(context).pop(id),
                  trailing: id == current
                      ? AppText(
                          context.strings.currentTag,
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

/// Half-sheet to pick thinking / reasoning effort.
Future<AiReasoningEffort?> showAiReasoningEffortSheet(
  BuildContext context, {
  required AiReasoningEffort current,
}) {
  return showAppSheet<AiReasoningEffort>(
    context: context,
    size: AppSheetSize.half,
    builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceXs,
              AppTheme.pagePadding,
              AppTheme.spaceXs,
            ),
            child: AppSectionHeader(
              context.strings.reasoningLabel,
              subtitle: context.strings.reasoningHint,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppTheme.spaceGroup,
                0,
                AppTheme.spaceMd,
              ),
              itemCount: AiReasoningEffort.values.length,
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final effort = AiReasoningEffort.values[index];
                final selected = effort == current;
                return AppListTile(
                  title: context.strings.reasoningEffortName(effort),
                  icon: selected
                      ? Icons.check_circle_outline
                      : Icons.circle_outlined,
                  onTap: () => Navigator.of(context).pop(effort),
                  trailing: selected
                      ? AppText(
                          context.strings.currentTag,
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

/// Chat chrome: pick model, then thinking effort (NT ModelThinkingDrawer).
Future<void> pickAndApplyTextModel(BuildContext context) async {
  final settings = AppScope.settingsOf(context);
  final catalog = AppScope.modelCatalogOf(context);
  final endpoint = settings.ai.text;

  List<String> models = const [];
  try {
    models = await catalog.listModels(AiEndpointConfig.fromText(endpoint));
  } on AiModelCatalogException {
    models = const [];
  } catch (_) {
    models = const [];
  }
  if (!context.mounted) return;

  if (models.isEmpty) {
    final current = endpoint.model.trim();
    final fallback = endpoint.kind.defaultModel.trim();
    if (current.isNotEmpty) {
      models = [current];
    } else if (fallback.isNotEmpty) {
      models = [fallback];
    } else {
      await pushAppSlide(
        context,
        const SettingsPage(
          initialSection: SettingsSection.ai,
        ),
      );
      return;
    }
  }

  final applied = await showAppSheet<bool>(
    context: context,
    size: AppSheetSize.half,
    builder: (context) => _ModelThinkingSheet(
      models: models,
      initialModel: endpoint.model,
      initialEffort: endpoint.reasoningEffort,
    ),
  );
  if (applied != true || !context.mounted) return;
}

class _ModelThinkingSheet extends StatefulWidget {
  const _ModelThinkingSheet({
    required this.models,
    required this.initialModel,
    required this.initialEffort,
  });

  final List<String> models;
  final String initialModel;
  final AiReasoningEffort initialEffort;

  @override
  State<_ModelThinkingSheet> createState() => _ModelThinkingSheetState();
}

class _ModelThinkingSheetState extends State<_ModelThinkingSheet> {
  late _ModelThinkingStep _step = _ModelThinkingStep.model;
  late String _model = widget.initialModel;
  late AiReasoningEffort _effort = widget.initialEffort;

  Future<void> _finish() async {
    final settings = AppScope.settingsOf(context);
    final endpoint = settings.ai.text;
    await settings.updateAi(
      settings.ai.withText(
        endpoint.copyWith(model: _model, reasoningEffort: _effort),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final onModel = _step == _ModelThinkingStep.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceXs,
            AppTheme.spaceSm,
            AppTheme.spaceXs,
          ),
          child: Row(
            children: [
              if (!onModel)
                AppCircleButton(
                  icon: Icons.arrow_back,
                  tooltip: context.strings.backAction,
                  size: 32,
                  iconSize: 18,
                  onPressed: () =>
                      setState(() => _step = _ModelThinkingStep.model),
                ),
              if (!onModel) const SizedBox(width: AppTheme.spaceXs),
              Expanded(
                child: AppSectionHeader(
                  onModel
                      ? context.strings.chooseModel
                      : context.strings.reasoningLabel,
                  subtitle: onModel
                      ? context.strings.chooseModelHint
                      : context.strings.reasoningHint,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: onModel
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    AppTheme.spaceGroup,
                    0,
                    AppTheme.spaceMd,
                  ),
                  itemCount: widget.models.length,
                  separatorBuilder: (_, _) => const SizedBox.shrink(),
                  itemBuilder: (context, index) {
                    final id = widget.models[index];
                    final selected = id == _model;
                    return AppListTile(
                      title: id,
                      icon: Icons.smart_toy_outlined,
                      onTap: () {
                        setState(() {
                          _model = id;
                          _step = _ModelThinkingStep.effort;
                        });
                      },
                      trailing: selected
                          ? AppText(
                              context.strings.currentTag,
                              role: AppTextRole.caption,
                            )
                          : null,
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    AppTheme.spaceGroup,
                    0,
                    AppTheme.spaceMd,
                  ),
                  itemCount: AiReasoningEffort.values.length,
                  separatorBuilder: (_, _) => const SizedBox.shrink(),
                  itemBuilder: (context, index) {
                    final effort = AiReasoningEffort.values[index];
                    final selected = effort == _effort;
                    return AppListTile(
                      title: context.strings.reasoningEffortName(effort),
                      icon: selected
                          ? Icons.check_circle_outline
                          : Icons.psychology_outlined,
                      onTap: () {
                        setState(() => _effort = effort);
                        _finish();
                      },
                      trailing: selected
                          ? AppText(
                              context.strings.currentTag,
                              role: AppTextRole.caption,
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
