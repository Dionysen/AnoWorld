/// Parsed SillyTavern / chara_card fields we care about (material only).
class StCharacterCard {
  const StCharacterCard({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMes = '',
    this.mesExample = '',
    this.systemPrompt = '',
    this.postHistoryInstructions = '',
    this.creatorNotes = '',
    this.alternateGreetings = const <String>[],
    this.bookEntries = const <StCharacterBookEntry>[],
    this.sourceLabel = '',
  });

  final String name;
  final String description;
  final String personality;
  final String scenario;
  final String firstMes;
  final String mesExample;
  final String systemPrompt;
  final String postHistoryInstructions;
  final String creatorNotes;
  final List<String> alternateGreetings;
  final List<StCharacterBookEntry> bookEntries;

  /// File name or other label for the confirm UI.
  final String sourceLabel;
}

class StCharacterBookEntry {
  const StCharacterBookEntry({
    required this.content,
    this.name = '',
    this.comment = '',
    this.keys = const <String>[],
    this.constant = false,
    this.enabled = true,
  });

  final String name;
  final String comment;
  final String content;
  final List<String> keys;
  final bool constant;
  final bool enabled;
}
