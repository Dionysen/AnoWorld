import 'package:anoworld/domain/ai/macro_context_builder.dart';
import 'package:anoworld/domain/ai/prompt_assembler.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';

/// Text AI call profile from global settings (preset + persona).
class AiPromptContext {
  const AiPromptContext({
    required this.endpoint,
    required this.generation,
    required this.promptManager,
    this.persona,
  });

  final AiTextEndpoint endpoint;
  final GenerationPreset generation;
  final PromptManagerConfig promptManager;
  final UserPersona? persona;

  String assembleSystem({
    Project? project,
    PlotElementCatalog? plotCatalog,
    String worldInfoBefore = '',
    required String taskSuffix,
    String worldInfoAfter = '',
  }) {
    final lore = project?.worldBook.combinedText ?? worldInfoBefore;
    final plotBlock = project == null || plotCatalog == null
        ? ''
        : plotCatalog.promptBlockForSelected(
            project.plotElements.selectedIds,
          );
    final after = [
      if (worldInfoAfter.trim().isNotEmpty) worldInfoAfter.trim(),
      if (plotBlock.isNotEmpty) plotBlock,
    ].join('\n\n');
    final macro = MacroContextBuilder().build(
      persona: persona,
      protagonist: project?.protagonist,
      cast: project?.cast ?? const [],
      modelName: endpoint.model,
    );
    return const PromptAssembler().assembleSystem(
      config: promptManager,
      macros: macro,
      taskSuffix: taskSuffix,
      worldInfoBefore: lore,
      worldInfoAfter: after,
    );
  }
}