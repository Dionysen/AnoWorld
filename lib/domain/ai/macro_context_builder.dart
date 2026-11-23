import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/foundation/ai/macro_service.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';

/// Fills [MacroContext] for SillyTavern-style expansion in prompts and lore.
class MacroContextBuilder {
  const MacroContextBuilder();

  MacroContext build({
    UserPersona? persona,
    CastMember? playAs,
    CastMember? protagonist,
    Iterable<CastMember> cast = const [],
    String scenario = '',
    String lastMessage = '',
    String lastUserMessage = '',
    String lastCharacterMessage = '',
    int messageCount = 0,
    String chatId = '',
    String modelName = '',
    String providerName = '',
    String currentInput = '',
    int maxContextTokens = 0,
    int maxResponseTokens = 0,
  }) {
    final hero = protagonist;
    final playerName = playAs?.name.trim() ?? '';
    final playerSummary = playAs?.summary.trim() ?? '';
    final groupNames = [
      for (final member in cast)
        if ((hero == null || member.id != hero.id) &&
            (playAs == null || member.id != playAs.id))
          member.name,
    ];
    return MacroContext(
      userName: playerName.isNotEmpty
          ? playerName
          : (persona?.name ?? 'User'),
      userDescription: playerSummary.isNotEmpty
          ? playerSummary
          : (persona?.description ?? ''),
      characterName: hero?.name ?? 'Assistant',
      characterDescription: hero?.summary ?? '',
      characterPersonality: hero?.personality ?? '',
      characterScenario: scenario,
      characterFirstMessage: '',
      characterExamples: hero == null
          ? ''
          : hero.exampleLines.join('\n'),
      characterSystemPrompt: persona?.systemPromptOverride ?? '',
      characterVersion: '1.0',
      postHistoryInstructions: persona?.postHistoryInstructions ?? '',
      chatId: chatId,
      messageCount: messageCount,
      lastMessage: lastMessage,
      lastUserMessage: lastUserMessage,
      lastCharacterMessage: lastCharacterMessage,
      currentInput: currentInput,
      modelName: modelName,
      providerName: providerName,
      groupCharacterNames: groupNames,
      maxContextTokens: maxContextTokens,
      maxResponseTokens: maxResponseTokens,
    );
  }
}