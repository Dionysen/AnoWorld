import 'package:anoworld/foundation/ai/macro_service.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';

/// Builds a single system string from ST prompt manager config + macros.
class PromptAssembler {
  const PromptAssembler();

  String assembleSystem({
    required PromptManagerConfig config,
    required MacroContext macros,
    required String taskSuffix,
    String worldInfoBefore = '',
    String worldInfoAfter = '',
    MacroService? macrosService,
  }) {
    final service = macrosService ?? MacroService(macros);
    final parts = <String>[];
    for (final section in config.enabledSections) {
      if (section.type == PromptSectionType.chatHistory) continue;
      final filled = _sectionText(
        section,
        macros,
        worldInfoBefore: worldInfoBefore,
        worldInfoAfter: worldInfoAfter,
      );
      final expanded = service.process(filled).trim();
      if (expanded.isEmpty) continue;
      parts.add(expanded);
    }
    final task = taskSuffix.trim();
    if (task.isNotEmpty) parts.add(task);
    return parts.join('\n\n');
  }

  String _sectionText(
    PromptSection section,
    MacroContext macros, {
    required String worldInfoBefore,
    required String worldInfoAfter,
  }) {
    if (section.type == PromptSectionType.worldInfo) {
      return worldInfoBefore.isNotEmpty
          ? worldInfoBefore
          : section.effectiveContent;
    }
    if (section.type == PromptSectionType.worldInfoAfter) {
      return worldInfoAfter.isNotEmpty
          ? worldInfoAfter
          : section.effectiveContent;
    }
    if (PromptSection.isTypeCharacterOwned(section.type)) {
      return switch (section.type) {
        PromptSectionType.characterDescription => macros.characterDescription,
        PromptSectionType.characterPersonality => macros.characterPersonality,
        PromptSectionType.characterScenario => macros.characterScenario,
        PromptSectionType.exampleMessages => macros.characterExamples,
        PromptSectionType.persona => macros.userDescription.isEmpty
            ? macros.userName
            : macros.userDescription,
        _ => '',
      };
    }
    return section.effectiveContent;
  }
}