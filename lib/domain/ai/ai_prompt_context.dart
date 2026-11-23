import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/domain/ai/macro_context_builder.dart';
import 'package:anoworld/domain/ai/play_context_selector.dart';
import 'package:anoworld/domain/ai/prompt_assembler.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
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

  /// Play-turn system prompt: rules + the lore and plot elements the scene
  /// actually needs.
  ///
  /// 必进项由宏与正文承担：主角字段走 [MacroContextBuilder]，主线概括与当前
  /// 站目标由各 action 写进 user 消息；这里只决定「设定正文与剧情元素」。
  ///
  /// With a [budget] the hit entries are chosen against what is left after the
  /// fixed rules and [reservedTokens] (the caller's user block), so a small
  /// 上下文长度 drops low-score lore instead of blowing the window.
  String assemblePlaySystem({
    required Project project,
    required String taskSuffix,
    PlotElementCatalog? plotCatalog,
    Iterable<String> recentText = const <String>[],
    PlayRole? playRole,
    ContextBudget? budget,
    int reservedTokens = 0,
  }) {
    final floor = assembleSystem(
      project: project,
      worldInfoBefore: '',
      worldInfoAfter: '',
      inlineWorldBook: false,
      playRole: playRole,
      taskSuffix: taskSuffix,
    );
    final selection = const PlayContextSelector().select(
      project: project,
      plotCatalog: plotCatalog,
      recentText: recentText,
      maxTokens: budget == null
          ? null
          : budget.remaining(budget.estimate(floor) + reservedTokens),
    );
    return assembleSystem(
      project: project,
      worldInfoBefore: selection.loreText,
      worldInfoAfter: selection.plotText,
      inlineWorldBook: false,
      playRole: playRole,
      taskSuffix: taskSuffix,
    );
  }

  String assembleSystem({
    Project? project,
    PlotElementCatalog? plotCatalog,
    String worldInfoBefore = '',
    PlayRole? playRole,
    required String taskSuffix,
    String worldInfoAfter = '',
    /// When false the full world book is not inlined and [worldInfoBefore] is
    /// used as the only lore block (the create-assistant L1 directory).
    bool inlineWorldBook = true,
  }) {
    final lore = inlineWorldBook
        ? (project?.worldBook.combinedText ?? worldInfoBefore)
        : worldInfoBefore;
    final plotBlock = project == null || plotCatalog == null
        ? ''
        : plotCatalog.promptBlockForSelected(
            project.plotElements.selectedIds,
          );
    final after = [
      if (worldInfoAfter.trim().isNotEmpty) worldInfoAfter.trim(),
      if (plotBlock.isNotEmpty) plotBlock,
    ].join('\n\n');
    final role = playRole;
    final playAs = role != null && project != null ? role.playerIn(project) : null;
    final focus = role != null && project != null
        ? role.focusIn(project)
        : project?.protagonist;
    final macro = MacroContextBuilder().build(
      persona: persona,
      playAs: playAs,
      protagonist: focus,
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