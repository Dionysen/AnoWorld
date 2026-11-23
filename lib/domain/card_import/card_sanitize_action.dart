import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/foundation/text/rich_text_sanitizer.dart';

class CardSanitizeSample {
  const CardSanitizeSample({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;
}

class CardSanitizeResult {
  const CardSanitizeResult({
    required this.draft,
    required this.changedFieldCount,
    required this.samples,
  });

  final StCardImportDraft draft;
  final int changedFieldCount;
  final List<CardSanitizeSample> samples;
}

/// Rule-based format cleanup on import draft (no LLM).
class CardSanitizeAction {
  const CardSanitizeAction({this.sanitizer = const RichTextSanitizer()});

  final RichTextSanitizer sanitizer;

  CardSanitizeResult run(StCardImportDraft draft, {int maxSamples = 5}) {
    var changes = 0;
    final samples = <CardSanitizeSample>[];

    void noteChange(String label, String before, String after) {
      if (before == after) return;
      changes++;
      if (samples.length < maxSamples) {
        samples.add(CardSanitizeSample(label: label, before: before, after: after));
      }
    }

    String clean(String value) => sanitizer.sanitize(value);

    final castItems = <StCardImportItem<CastMember>>[];
    for (final item in draft.castItems) {
      final v = item.value;
      final summary = clean(v.summary);
      final personality = clean(v.personality);
      final speech = clean(v.speechStyle);
      final lines = v.exampleLines
          .map(clean)
          .where((l) => l.trim().isNotEmpty)
          .toList(growable: false);
      noteChange('${item.title} · 简介', v.summary, summary);
      final next = v.copyWith(
        summary: summary,
        personality: personality,
        speechStyle: speech,
        exampleLines: lines,
      );
      castItems.add(
        item.copyWith(
          preview: previewCast(next),
          value: next,
        ),
      );
    }

    final worldItems = <StCardImportItem<WorldBookEntry>>[];
    for (final item in draft.worldBookItems) {
      final body = clean(item.value.body);
      noteChange(item.title, item.value.body, body);
      final next = item.value.copyWith(body: body);
      worldItems.add(
        item.copyWith(
          preview: previewText(body),
          value: next,
        ),
      );
    }

    final note = draft.cardAiNote == null ? null : clean(draft.cardAiNote!);
    if (draft.cardAiNote != null && note != draft.cardAiNote) {
      noteChange('卡内 AI 说明', draft.cardAiNote!, note!);
    }

    final cardMeta = draft.cardMeta;
    final creatorNotes = clean(cardMeta.creatorNotes);
    noteChange('作者注', cardMeta.creatorNotes, creatorNotes);

    final next = draft.copyWith(
      castItems: castItems,
      worldBookItems: worldItems,
      cardAiNote: note,
      cardMeta: cardMeta.copyWith(creatorNotes: creatorNotes),
    );

    return CardSanitizeResult(
      draft: next,
      changedFieldCount: changes,
      samples: samples,
    );
  }

  static String previewCast(CastMember m) {
    final parts = <String>[
      if (m.summary.trim().isNotEmpty) m.summary.trim(),
      if (m.personality.trim().isNotEmpty) '性格：${m.personality.trim()}',
    ];
    return _compactPreview(parts.join('\n'));
  }

  static String previewText(String text) => _compactPreview(text);

  static String _compactPreview(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 72) return compact;
    return '${compact.substring(0, 72)}…';
  }
}