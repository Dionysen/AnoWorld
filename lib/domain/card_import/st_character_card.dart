import 'dart:typed_data';

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
    this.creator = '',
    this.characterVersion = '',
    this.tags = const <String>[],
    this.creationDate = '',
    this.modificationDate = '',
    this.alternateGreetings = const <String>[],
    this.bookEntries = const <StCharacterBookEntry>[],
    this.sourceLabel = '',
    this.coverImageBytes,
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

  /// Card author, kept as story metadata (`meta.card`).
  final String creator;

  /// Card revision (`character_version`), kept as story metadata.
  final String characterVersion;

  /// Card tags, kept as story metadata.
  final List<String> tags;

  /// Display string from CCv3 `creation_date` or ST `create_date`.
  final String creationDate;

  /// Display string from CCv3 `modification_date`.
  final String modificationDate;

  final List<String> alternateGreetings;
  final List<StCharacterBookEntry> bookEntries;

  /// File name or other label for the confirm UI.
  final String sourceLabel;

  /// PNG card image bytes used as the story cover (null for JSON-only cards).
  final Uint8List? coverImageBytes;

  StCharacterCard copyWith({
    Uint8List? coverImageBytes,
    String? creationDate,
    String? modificationDate,
  }) {
    return StCharacterCard(
      name: name,
      description: description,
      personality: personality,
      scenario: scenario,
      firstMes: firstMes,
      mesExample: mesExample,
      systemPrompt: systemPrompt,
      postHistoryInstructions: postHistoryInstructions,
      creatorNotes: creatorNotes,
      creator: creator,
      characterVersion: characterVersion,
      tags: tags,
      creationDate: creationDate ?? this.creationDate,
      modificationDate: modificationDate ?? this.modificationDate,
      alternateGreetings: alternateGreetings,
      bookEntries: bookEntries,
      sourceLabel: sourceLabel,
      coverImageBytes: coverImageBytes ?? this.coverImageBytes,
    );
  }
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
