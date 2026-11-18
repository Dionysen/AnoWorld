import 'package:anoworld/domain/card_import/card_organize_cast_line_scanner.dart';
import 'package:anoworld/domain/card_import/card_organize_character_names.dart';
import 'package:anoworld/domain/card_import/card_organize_models.dart';
import 'package:anoworld/domain/card_import/card_organize_name_anchor.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';

/// Conservative, format-agnostic fallback when the LLM yields nothing useful.
class CardOrganizeHeuristic {
  const CardOrganizeHeuristic({this.maxSlicesPerWorld = 80});

  final int maxSlicesPerWorld;

  List<CardOrganizeOperation> buildOperations(StCardImportDraft draft) {
    final ops = <CardOrganizeOperation>[];

    for (final item in draft.worldBookItems) {
      final worldId = item.sourceId ?? 'world:${item.id}';
      final body = item.value.body.trim();
      if (body.isEmpty) continue;

      final kvLines = CardOrganizeCastLineScanner.scan(body);
      if (kvLines.length >= 2) {
        final castSlices = _slicesFromKvLines(kvLines, draft);
        if (castSlices.length >= 2) {
          ops.add(
            CardOrganizeOperation(
              op: 'split_cast',
              fromSourceId: worldId,
              castSlices: castSlices,
            ),
          );
          continue;
        }
      }

      final blocks = _splitMarkedBlocks(body, draft);
      if (blocks.length >= 2) {
        final castSlices = <CardOrganizeCastSlice>[];
        for (final slice in blocks) {
          if (castSlices.length >= maxSlicesPerWorld) break;
          final text = slice.text.trim();
          if (text.isEmpty) continue;
          final name = slice.name?.trim();
          if (name == null || name.isEmpty) continue;
          final castId = _matchCastId(name, draft);
          if (castId == null &&
              !CardOrganizeCharacterNames.isPlausibleNewCharacterName(
                name,
                bodyChars: text.length,
              )) {
            continue;
          }
          castSlices.add(
            CardOrganizeCastSlice(
              name: castId == null ? name : null,
              castItemId: castId,
              personality: text,
            ),
          );
        }
        if (castSlices.length >= 2) {
          ops.add(
            CardOrganizeOperation(
              op: 'split_cast',
              fromSourceId: worldId,
              castSlices: castSlices,
            ),
          );
          continue;
        }
      }

      final byKnownNames = _slicesForKnownCast(body, draft);
      if (byKnownNames.length >= 2) {
        ops.add(
          CardOrganizeOperation(
            op: 'split_cast',
            fromSourceId: worldId,
            castSlices:
                byKnownNames.take(maxSlicesPerWorld).toList(growable: false),
          ),
        );
        continue;
      }

      if (byKnownNames.length == 1) {
        final slice = byKnownNames.first;
        final text = slice.personality?.trim() ?? '';
        if (text.isNotEmpty && slice.castItemId != null) {
          ops.add(
            CardOrganizeOperation(
              op: 'extract_to_cast',
              fromSourceId: worldId,
              castItemId: slice.castItemId,
              target: 'cast.personality',
              body: text,
            ),
          );
        }
      }
    }

    return ops;
  }

  List<CardOrganizeCastSlice> _slicesFromKvLines(
    List<({String name, String line})> lines,
    StCardImportDraft draft,
  ) {
    final castSlices = <CardOrganizeCastSlice>[];
    for (final row in lines) {
      if (castSlices.length >= maxSlicesPerWorld) break;
      final castId = _matchCastId(row.name, draft);
      castSlices.add(
        CardOrganizeCastSlice(
          name: castId == null ? row.name : null,
          castItemId: castId,
          personality: row.line,
        ),
      );
    }
    return castSlices;
  }

  String? _matchCastId(String name, StCardImportDraft draft) {
    for (final item in draft.castItems) {
      if (item.value.name.trim() == name) return item.id;
    }
    return null;
  }

  List<({String? name, String text})> _splitMarkedBlocks(
    String body,
    StCardImportDraft draft,
  ) {
    final heads = <({int start, String name})>[];

    void addMatches(RegExp pattern, int nameGroup) {
      for (final m in pattern.allMatches(body)) {
        final name = m.group(nameGroup)?.trim();
        if (name == null || name.isEmpty) continue;
        if (CardOrganizeCharacterNames.isFieldLabel(name)) continue;
        if (!CardOrganizeNameAnchor.isAnchoredInSource(name, body)) continue;
        heads.add((start: m.start, name: name));
      }
    }

    addMatches(
      RegExp(r'(?:^|\n)【\s*([^】\n]{1,32})\s*】', multiLine: true),
      1,
    );
    addMatches(
      RegExp(r'(?:^|\n)\s*#{1,3}\s+([^\n]{1,32})\s*$', multiLine: true),
      1,
    );
    addMatches(
      RegExp(r'\*\*\s*([^*\n]{1,32})\s*\*\*'),
      1,
    );

    if (heads.length < 2) return const [];

    heads.sort((a, b) => a.start.compareTo(b.start));
    final slices = <({String? name, String text})>[];
    for (var i = 0; i < heads.length; i++) {
      final h = heads[i];
      final end = i + 1 < heads.length ? heads[i + 1].start : body.length;
      final text = body.substring(h.start, end).trim();
      if (text.isNotEmpty) {
        slices.add((name: h.name, text: text));
      }
    }
    return slices;
  }

  List<CardOrganizeCastSlice> _slicesForKnownCast(
    String body,
    StCardImportDraft draft,
  ) {
    final slices = <CardOrganizeCastSlice>[];
    for (final item in draft.castItems) {
      final name = item.value.name.trim();
      if (name.isEmpty) continue;
      if (CardOrganizeCharacterNames.isFieldLabel(name)) continue;
      if (!CardOrganizeNameAnchor.isAnchoredInSource(name, body)) continue;
      final idx = body.indexOf(name);
      if (idx < 0) continue;
      final start = _paragraphStart(body, idx);
      final end = _paragraphEnd(body, idx + name.length);
      final paragraph = body.substring(start, end).trim();
      if (paragraph.length < name.length + 12) continue;
      slices.add(
        CardOrganizeCastSlice(
          castItemId: item.id,
          personality: paragraph,
        ),
      );
    }
    return slices;
  }

  int _paragraphStart(String body, int index) {
    final prev = body.lastIndexOf('\n\n', index);
    if (prev < 0) return 0;
    return prev + 2;
  }

  int _paragraphEnd(String body, int index) {
    final next = body.indexOf('\n\n', index);
    if (next < 0) return body.length;
    return next;
  }
}