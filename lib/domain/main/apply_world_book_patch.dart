import 'package:anoworld/domain/models/world_book.dart';

/// Applies world-book ops onto [base].
class ApplyWorldBookPatch {
  const ApplyWorldBookPatch();

  WorldBook apply(WorldBook base, List<Map<String, dynamic>> ops) {
    final entries = Map<String, WorldBookEntry>.from(
      {for (final e in base.entries) e.id: e},
    );
    var seq = entries.length;

    for (final raw in ops) {
      final op = (raw['op']?.toString() ?? '').trim();
      switch (op) {
        case 'upsert_entry':
          final title = raw['title']?.toString().trim() ?? '';
          final body = raw['body']?.toString().trim() ?? '';
          if (title.isEmpty && body.isEmpty) {
            throw const ApplyWorldBookPatchException('设定标题与正文不能都空');
          }
          final givenId = raw['id']?.toString().trim();
          final id = (givenId != null && givenId.isNotEmpty)
              ? givenId
              : () {
                  seq++;
                  return 'wb_p_$seq';
                }();
          final existing = entries[id];
          final keysRaw = raw['keys'];
          final keys = keysRaw is List
              ? keysRaw
                  .whereType<String>()
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(growable: false)
              : existing?.keys ?? const <String>[];
          entries[id] = WorldBookEntry(
            id: id,
            title: title.isEmpty ? (existing?.title ?? '设定') : title,
            body: body.isEmpty ? (existing?.body ?? '') : body,
            alwaysOn: raw.containsKey('alwaysOn')
                ? raw['alwaysOn'] == true
                : (existing?.alwaysOn ?? false),
            keys: keys,
          );
        case 'remove_entry':
          final id = raw['id']?.toString().trim() ?? '';
          if (id.isEmpty || !entries.containsKey(id)) {
            throw ApplyWorldBookPatchException('删不了设定：$id');
          }
          entries.remove(id);
        default:
          if (op.isNotEmpty) {
            throw ApplyWorldBookPatchException('不支持的操作：$op');
          }
      }
    }

    return WorldBook(
      entries: List<WorldBookEntry>.unmodifiable(entries.values),
    );
  }
}

class ApplyWorldBookPatchException implements Exception {
  const ApplyWorldBookPatchException(this.message);

  final String message;

  @override
  String toString() => message;
}
