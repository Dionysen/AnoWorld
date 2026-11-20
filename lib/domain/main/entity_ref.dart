/// Which story layer an [EntityRef] points at.
enum EntityKind {
  preset,
  worldBook,
  cast,
  node,
  edge,
  plotElement;

  /// Stable text prefix used inside refs.
  String get prefix => switch (this) {
        EntityKind.preset => 'preset',
        EntityKind.worldBook => 'wb',
        EntityKind.cast => 'cast',
        EntityKind.node => 'node',
        EntityKind.edge => 'edge',
        EntityKind.plotElement => 'pe',
      };

  /// Addressable field names per layer.
  Set<String> get fields => switch (this) {
        EntityKind.preset => const {'name', 'description'},
        EntityKind.worldBook =>
          const {'title', 'body', 'keys', 'alwaysOn'},
        EntityKind.cast => const {
            'name',
            'summary',
            'personality',
            'speechStyle',
            'exampleLines',
            'isProtagonist',
          },
        EntityKind.node => const {'title', 'synopsis', 'tags'},
        EntityKind.edge => const {'from', 'to', 'kind', 'label', 'detail'},
        EntityKind.plotElement =>
          const {'keyword', 'description', 'categoryId'},
      };

  static EntityKind? fromPrefix(String raw) {
    final key = raw.trim().toLowerCase();
    for (final kind in EntityKind.values) {
      if (kind.prefix == key) return kind;
    }
    return null;
  }
}

/// Address of one story entity, optionally narrowed to a single field.
///
/// Format: `<prefix>:<id>` or `<prefix>:<id>.<field>`, e.g. `wb:wb_03`,
/// `cast:c_02.speechStyle`, `edge:e_p_1.detail`.
///
/// Refs are a conversation-level address only; ids on disk stay untouched.
class EntityRef {
  const EntityRef({required this.kind, required this.id, this.field});

  final EntityKind kind;
  final String id;

  /// Single field name; null addresses the whole entity.
  final String? field;

  bool get hasField => field != null;

  /// `wb:wb_03.body` style string, round-trips through [parse].
  String format() => field == null
      ? '${kind.prefix}:$id'
      : '${kind.prefix}:$id.$field';

  @override
  String toString() => format();

  /// Parses [raw]; returns null when it is not a well-formed ref.
  static EntityRef? tryParse(String raw) {
    try {
      return parse(raw);
    } on EntityRefException {
      return null;
    }
  }

  /// Parses [raw], throwing a readable [EntityRefException] on bad input.
  static EntityRef parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const EntityRefException('引用为空');
    }
    final colon = text.indexOf(':');
    if (colon <= 0 || colon == text.length - 1) {
      throw EntityRefException('引用缺少「层:id」：$text');
    }
    final kind = EntityKind.fromPrefix(text.substring(0, colon));
    if (kind == null) {
      throw EntityRefException('认不出这一层：${text.substring(0, colon)}');
    }
    final rest = text.substring(colon + 1).trim();
    final dot = rest.indexOf('.');
    final id = (dot < 0 ? rest : rest.substring(0, dot)).trim();
    if (id.isEmpty) {
      throw EntityRefException('引用缺少 id：$text');
    }
    if (dot < 0) return EntityRef(kind: kind, id: id);
    final field = rest.substring(dot + 1).trim();
    if (field.isEmpty) {
      throw EntityRefException('引用缺少字段名：$text');
    }
    if (!kind.fields.contains(field)) {
      throw EntityRefException('${kind.prefix} 没有这个字段：$field');
    }
    return EntityRef(kind: kind, id: id, field: field);
  }
}

class EntityRefException implements Exception {
  const EntityRefException(this.message);

  final String message;

  @override
  String toString() => message;
}
