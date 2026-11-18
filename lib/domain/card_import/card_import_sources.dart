import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/foundation/text/rich_text_sanitizer.dart';

class CardImportSource {
  const CardImportSource({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.castItemId,
    required this.worldItemId,
  });

  final String id;
  final String kind;
  final String title;
  final String body;

  /// Set when [kind] targets a cast field.
  final String? castItemId;

  /// Set when [kind] targets world book content.
  final String? worldItemId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': 1,
        'id': id,
        'kind': kind,
        'title': title,
        'body': body,
        if (castItemId != null) 'castItemId': castItemId,
        if (worldItemId != null) 'worldItemId': worldItemId,
      };
}

class CardImportSources {
  const CardImportSources({
    this.sanitizer = const RichTextSanitizer(),
    this.maxBodyChars = 6000,
  });

  final RichTextSanitizer sanitizer;
  final int maxBodyChars;

  List<CardImportSource> fromDraft(StCardImportDraft draft) {
    final out = <CardImportSource>[];

    for (final item in draft.castItems) {
      final id = item.sourceId ?? 'cast:${item.id}';
      final v = item.value;
      void addField(String kind, String title, String body) {
        final trimmed = body.trim();
        if (trimmed.isEmpty) return;
        out.add(
          CardImportSource(
            id: '$id:$kind',
            kind: kind,
            title: title,
            body: _clip(trimmed),
            castItemId: item.id,
            worldItemId: null,
          ),
        );
      }

      addField('summary', '${item.title} · 简介', v.summary);
      addField('personality', '${item.title} · 性格', v.personality);
      addField('speechStyle', '${item.title} · 说话', v.speechStyle);
      for (var i = 0; i < v.exampleLines.length; i++) {
        addField('exampleLine', '${item.title} · 例句 ${i + 1}', v.exampleLines[i]);
      }
    }

    for (final item in draft.worldBookItems) {
      final body = item.value.body.trim();
      if (body.isEmpty) continue;
      out.add(
        CardImportSource(
          id: item.sourceId ?? 'world:${item.id}',
          kind: 'worldBook.body',
          title: item.title,
          body: _clip(body),
          castItemId: null,
          worldItemId: item.id,
        ),
      );
    }

    return out;
  }

  String _clip(String text) {
    if (text.length <= maxBodyChars) return text;
    return '${text.substring(0, maxBodyChars)}…';
  }

  String? normalizedBodyFor(String sourceId, List<CardImportSource> sources) {
    for (final s in sources) {
      if (s.id == sourceId) {
        return sanitizer.normalizeForFingerprint(s.body);
      }
    }
    return null;
  }

  bool isSubstringOfSource(String sourceId, String fragment, List<CardImportSource> sources) {
    final normSource = normalizedBodyFor(sourceId, sources);
    if (normSource == null) return false;
    final normFrag = sanitizer.normalizeForFingerprint(fragment);
    if (normFrag.isEmpty) return false;
    return normSource.contains(normFrag);
  }
}