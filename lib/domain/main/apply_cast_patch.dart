import 'package:anoworld/domain/models/cast.dart';

/// Applies cast ops onto [base].
class ApplyCastPatch {
  const ApplyCastPatch();

  List<CastMember> apply(
    List<CastMember> base,
    List<Map<String, dynamic>> ops,
  ) {
    final members = Map<String, CastMember>.from(
      {for (final c in base) c.id: c},
    );
    var seq = members.length;

    for (final raw in ops) {
      final op = (raw['op']?.toString() ?? '').trim();
      switch (op) {
        case 'upsert_member':
          final name = raw['name']?.toString().trim() ?? '';
          if (name.isEmpty && raw['id'] == null) {
            throw const ApplyCastPatchException('角色名不能为空');
          }
          final givenId = raw['id']?.toString().trim();
          final id = (givenId != null && givenId.isNotEmpty)
              ? givenId
              : () {
                  seq++;
                  return 'c_p_$seq';
                }();
          final existing = members[id];
          final nextName =
              name.isEmpty ? (existing?.name ?? '') : name;
          if (nextName.isEmpty) {
            throw const ApplyCastPatchException('角色名不能为空');
          }
          final exampleLinesRaw = raw['exampleLines'];
          final exampleLines = exampleLinesRaw is List
              ? exampleLinesRaw
                  .map((s) => s.toString().trim())
                  .where((s) => s.isNotEmpty)
                  .toList(growable: false)
              : (existing?.exampleLines ?? const <String>[]);
          members[id] = CastMember(
            id: id,
            name: nextName,
            summary: raw['summary']?.toString() ?? existing?.summary ?? '',
            personality:
                raw['personality']?.toString() ?? existing?.personality ?? '',
            speechStyle:
                raw['speechStyle']?.toString() ?? existing?.speechStyle ?? '',
            exampleLines: exampleLines,
            avatarAssetId: existing?.avatarAssetId,
            isProtagonist: raw.containsKey('isProtagonist')
                ? raw['isProtagonist'] == true
                : (existing?.isProtagonist ?? false),
          );
        case 'remove_member':
          final id = raw['id']?.toString().trim() ?? '';
          if (id.isEmpty || !members.containsKey(id)) {
            throw ApplyCastPatchException('删不了角色：$id');
          }
          members.remove(id);
        default:
          if (op.isNotEmpty) {
            throw ApplyCastPatchException('不支持的操作：$op');
          }
      }
    }

    // Keep at most one protagonist.
    final list = members.values.toList(growable: true);
    final protagonists = list.where((c) => c.isProtagonist).toList();
    if (protagonists.length > 1) {
      final keep = protagonists.first.id;
      for (var i = 0; i < list.length; i++) {
        if (list[i].isProtagonist && list[i].id != keep) {
          list[i] = list[i].copyWith(isProtagonist: false);
        }
      }
    }
    return List<CastMember>.unmodifiable(list);
  }
}

class ApplyCastPatchException implements Exception {
  const ApplyCastPatchException(this.message);

  final String message;

  @override
  String toString() => message;
}
