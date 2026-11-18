import 'package:anoworld/domain/card_import/card_import_sources.dart';
import 'package:anoworld/domain/card_import/card_organize_character_names.dart';
import 'package:anoworld/domain/card_import/card_organize_models.dart';
import 'package:anoworld/domain/card_import/card_organize_name_anchor.dart';

/// Drops cast operations whose names are labels or not anchored in source text.
class CardOrganizeOperationSanitizer {
  const CardOrganizeOperationSanitizer();

  List<CardOrganizeOperation> filter(
    List<CardOrganizeOperation> operations,
    List<CardImportSource> sources,
  ) {
    final out = <CardOrganizeOperation>[];
    for (final op in operations) {
      final kept = _filterOne(op, sources);
      if (kept != null) out.add(kept);
    }
    return out;
  }

  CardOrganizeOperation? _filterOne(
    CardOrganizeOperation op,
    List<CardImportSource> sources,
  ) {
    final sourceBody = _bodyForSource(op.fromSourceId, sources);
    switch (op.op) {
      case 'add_cast':
        final name = op.castName?.trim() ?? '';
        if (!_acceptName(name, op.body?.length ?? 0, sourceBody)) return null;
        return op;
      case 'split_cast':
        final slices = <CardOrganizeCastSlice>[];
        for (final slice in op.castSlices) {
          if (slice.castItemId != null && slice.castItemId!.trim().isNotEmpty) {
            slices.add(slice);
            continue;
          }
          final name = slice.name?.trim() ?? '';
          final bodyLen = _sliceBodyChars(slice);
          if (_acceptName(name, bodyLen, sourceBody)) slices.add(slice);
        }
        if (slices.isEmpty) return null;
        return CardOrganizeOperation(
          op: op.op,
          fromSourceId: op.fromSourceId,
          target: op.target,
          castItemId: op.castItemId,
          body: op.body,
          castName: op.castName,
          entries: op.entries,
          castSlices: slices,
        );
      default:
        return op;
    }
  }

  String _bodyForSource(String id, List<CardImportSource> sources) {
    for (final s in sources) {
      if (s.id == id) return s.body;
    }
    for (final s in sources) {
      if (s.id.startsWith(id) || id.startsWith(s.id)) return s.body;
    }
    return '';
  }

  bool _acceptName(String name, int bodyChars, String sourceBody) {
    if (name.isEmpty) return false;
    if (!CardOrganizeCharacterNames.isPlausibleNewCharacterName(
      name,
      bodyChars: bodyChars,
    )) {
      return false;
    }
    if (sourceBody.isEmpty) return true;
    return CardOrganizeNameAnchor.isAnchoredInSource(name, sourceBody);
  }

  int _sliceBodyChars(CardOrganizeCastSlice slice) {
    for (final text in [
      slice.personality,
      slice.summary,
      slice.speechStyle,
    ]) {
      final t = text?.trim();
      if (t != null && t.isNotEmpty) return t.length;
    }
    return 0;
  }
}