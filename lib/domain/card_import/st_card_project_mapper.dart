import 'package:anoworld/domain/card_import/st_character_card.dart';
import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/domain/project/project_factory.dart';

/// One confirm-row the user can keep or drop before writing a project.
class StCardImportItem<T> {
  const StCardImportItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.value,
    this.included = true,
  });

  final String id;
  final String title;
  final String preview;
  final T value;
  final bool included;

  StCardImportItem<T> copyWith({bool? included}) {
    return StCardImportItem<T>(
      id: id,
      title: title,
      preview: preview,
      value: value,
      included: included ?? this.included,
    );
  }
}

/// Editable import draft: maps ST cards → Background / Cast.
class StCardImportDraft {
  const StCardImportDraft({
    required this.title,
    required this.castItems,
    required this.backgroundItems,
    this.cardAiNote,
  });

  final String title;
  final List<StCardImportItem<CastMember>> castItems;
  final List<StCardImportItem<BackgroundEntry>> backgroundItems;

  /// 卡内 system/post-history 提示（不写进故事包，仅导入页说明）。
  final String? cardAiNote;

  StCardImportDraft copyWith({
    String? title,
    List<StCardImportItem<CastMember>>? castItems,
    List<StCardImportItem<BackgroundEntry>>? backgroundItems,
    String? cardAiNote,
  }) {
    return StCardImportDraft(
      title: title ?? this.title,
      castItems: castItems ?? this.castItems,
      backgroundItems: backgroundItems ?? this.backgroundItems,
      cardAiNote: cardAiNote ?? this.cardAiNote,
    );
  }

  /// Builds a blank-main project filled with selected material.
  Project toProject({
    required String id,
    DateTime? now,
    ProjectFactory factory = const ProjectFactory(),
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    final blank = factory.createBlank(
      id: id,
      title: title.trim().isEmpty ? '未命名故事' : title.trim(),
      now: stamp,
    );
    final cast = castItems
        .where((item) => item.included)
        .map((item) => item.value)
        .toList(growable: false);
    final entries = backgroundItems
        .where((item) => item.included)
        .map((item) => item.value)
        .toList(growable: false);
    return blank.copyWith(
      background: Background(entries: entries),
      cast: cast,
    );
  }
}

/// Maps one or more ST cards into a confirmable [StCardImportDraft].
class StCardProjectMapper {
  const StCardProjectMapper();

  StCardImportDraft fromCards(List<StCharacterCard> cards) {
    if (cards.isEmpty) {
      throw ArgumentError('cards must not be empty');
    }
    final primary = cards.first;
    final castItems = <StCardImportItem<CastMember>>[];
    final backgroundItems = <StCardImportItem<BackgroundEntry>>[];

    for (var cardIndex = 0; cardIndex < cards.length; cardIndex++) {
      final card = cards[cardIndex];
      final castId = newEntityId('c');
      castItems.add(
        StCardImportItem(
          id: castId,
          title: card.name,
          preview: _preview(
            [
              if (card.description.trim().isNotEmpty) card.description.trim(),
              if (card.personality.trim().isNotEmpty)
                '性格：${card.personality.trim()}',
            ].join('\n'),
          ),
          value: CastMember(
            id: castId,
            name: card.name,
            summary: card.description.trim(),
            personality: card.personality.trim(),
            speechStyle: '',
            exampleLines: _exampleLines(card.mesExample),
            isProtagonist: cardIndex == 0,
          ),
        ),
      );

      if (card.scenario.trim().isNotEmpty) {
        final id = newEntityId('bg');
        backgroundItems.add(
          StCardImportItem(
            id: id,
            title: cards.length == 1 ? '情景' : '情景 · ${card.name}',
            preview: _preview(card.scenario),
            value: BackgroundEntry(
              id: id,
              title: cards.length == 1 ? '情景' : '情景 · ${card.name}',
              body: card.scenario.trim(),
              alwaysOn: true,
            ),
          ),
        );
      }

      if (card.firstMes.trim().isNotEmpty) {
        final id = newEntityId('bg');
        backgroundItems.add(
          StCardImportItem(
            id: id,
            title: cards.length == 1 ? '开场素材' : '开场素材 · ${card.name}',
            preview: _preview(card.firstMes),
            value: BackgroundEntry(
              id: id,
              title: cards.length == 1 ? '开场素材' : '开场素材 · ${card.name}',
              body: card.firstMes.trim(),
              alwaysOn: true,
            ),
          ),
        );
      }

      for (var i = 0; i < card.alternateGreetings.length; i++) {
        final text = card.alternateGreetings[i].trim();
        if (text.isEmpty) continue;
        final id = newEntityId('bg');
        backgroundItems.add(
          StCardImportItem(
            id: id,
            title: '备选开场 ${i + 1}',
            preview: _preview(text),
            value: BackgroundEntry(
              id: id,
              title: '备选开场 ${i + 1}',
              body: text,
              alwaysOn: false,
              keys: const ['开场', '问候'],
            ),
            included: false,
          ),
        );
      }

      for (final entry in card.bookEntries) {
        if (!entry.enabled || entry.content.trim().isEmpty) continue;
        final id = newEntityId('bg');
        final title = _bookTitle(entry);
        backgroundItems.add(
          StCardImportItem(
            id: id,
            title: title,
            preview: _preview(entry.content),
            value: BackgroundEntry(
              id: id,
              title: title,
              body: entry.content.trim(),
              alwaysOn: entry.constant,
              keys: entry.constant ? const <String>[] : entry.keys,
            ),
          ),
        );
      }
    }

    return StCardImportDraft(
      title: primary.name,
      castItems: castItems,
      backgroundItems: backgroundItems,
      cardAiNote: _cardAiNote(cards),
    );
  }

  String? _cardAiNote(List<StCharacterCard> cards) {
    final parts = <String>[];
    for (final card in cards) {
      if (card.systemPrompt.trim().isNotEmpty) {
        parts.add(card.systemPrompt.trim());
      }
      if (card.postHistoryInstructions.trim().isNotEmpty) {
        parts.add(card.postHistoryInstructions.trim());
      }
    }
    if (parts.isEmpty) return null;
    final joined = parts.join('\n\n');
    return joined.length > 160 ? '${joined.substring(0, 160)}…' : joined;
  }

  static String _bookTitle(StCharacterBookEntry entry) {
    final name = entry.name.trim();
    if (name.isNotEmpty) return name;
    final comment = entry.comment.trim();
    if (comment.isNotEmpty) return comment;
    if (entry.keys.isNotEmpty) return entry.keys.first;
    return '设定条目';
  }

  static List<String> _exampleLines(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    final chunks = trimmed
        .split(RegExp(r'<START>', caseSensitive: false))
        .expand((chunk) => chunk.split(RegExp(r'[\r\n]+')))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (chunks.length <= 12) return chunks;
    return chunks.take(12).toList(growable: false);
  }

  static String _preview(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 72) return compact;
    return '${compact.substring(0, 72)}…';
  }
}
