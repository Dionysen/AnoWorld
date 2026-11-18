import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';

class CardOrganizeOperation {
  const CardOrganizeOperation({
    required this.op,
    required this.fromSourceId,
    this.target,
    this.castItemId,
    this.body,
    this.castName,
    this.entries = const [],
    this.castSlices = const [],
  });

  factory CardOrganizeOperation.fromJson(Map<String, dynamic> json) {
    final op = json['op']?.toString() ?? '';
    final entriesRaw = json['entries'];
    final entries = <CardOrganizeSplitEntry>[];
    if (entriesRaw is List) {
      for (final item in entriesRaw) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        entries.add(
          CardOrganizeSplitEntry(
            title: row['title']?.toString() ?? '设定',
            body: row['body']?.toString() ?? '',
            alwaysOn: row['alwaysOn'] == true,
            keys: row['keys'] is List
                ? (row['keys'] as List)
                    .map((e) => e.toString())
                    .toList(growable: false)
                : const <String>[],
          ),
        );
      }
    }
    final slices = <CardOrganizeCastSlice>[];
    final castsRaw = json['casts'];
    if (castsRaw is List) {
      for (final item in castsRaw) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        slices.add(CardOrganizeCastSlice.fromJson(row));
      }
    }

    return CardOrganizeOperation(
      op: op,
      fromSourceId: json['fromSourceId']?.toString() ?? '',
      target: json['target']?.toString(),
      castItemId: json['castItemId']?.toString(),
      body: json['body']?.toString(),
      castName: json['name']?.toString() ?? json['castName']?.toString(),
      entries: entries,
      castSlices: slices,
    );
  }

  final String op;
  final String fromSourceId;

  /// `extract_to_cast` / legacy `move`: `cast.summary` etc.
  final String? target;
  final String? castItemId;

  /// Substring from [fromSourceId] for extract / update_world.
  final String? body;

  /// `add_cast`: display name for a new cast row.
  final String? castName;
  final List<CardOrganizeSplitEntry> entries;

  /// `split_cast`: multiple characters from one world entry.
  final List<CardOrganizeCastSlice> castSlices;
}

/// One character slice from a shared world-book body (all fields are source substrings).
class CardOrganizeCastSlice {
  const CardOrganizeCastSlice({
    this.name,
    this.castItemId,
    this.summary,
    this.personality,
    this.speechStyle,
  });

  factory CardOrganizeCastSlice.fromJson(Map<String, dynamic> json) {
    return CardOrganizeCastSlice(
      name: json['name']?.toString(),
      castItemId: json['castItemId']?.toString(),
      summary: json['summary']?.toString(),
      personality: json['personality']?.toString(),
      speechStyle: json['speechStyle']?.toString(),
    );
  }

  final String? name;
  final String? castItemId;
  final String? summary;
  final String? personality;
  final String? speechStyle;
}

class CardOrganizeSplitEntry {
  const CardOrganizeSplitEntry({
    required this.title,
    required this.body,
    required this.alwaysOn,
    required this.keys,
  });

  final String title;
  final String body;
  final bool alwaysOn;
  final List<String> keys;
}

class CardOrganizeException implements Exception {
  const CardOrganizeException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CardOrganizeProposal {
  const CardOrganizeProposal({
    required this.draftBefore,
    required this.draftAfter,
    required this.changes,
  });

  final StCardImportDraft draftBefore;
  final StCardImportDraft draftAfter;
  final List<CardOrganizeChangeLine> changes;
}

class CardOrganizeChangeLine {
  const CardOrganizeChangeLine({
    required this.label,
    required this.detail,
  });

  final String label;
  final String detail;
}