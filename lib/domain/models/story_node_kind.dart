/// Station role on the main graph (stored in [StoryNode.tags] as the enum name).
///
/// Expand later by appending values; keep [ending] name for existing packs.
enum StoryNodeKind {
  opening,
  scene,
  turning,
  ending;

  /// User-facing short label.
  String get label => switch (this) {
        StoryNodeKind.opening => '开场',
        StoryNodeKind.scene => '过程',
        StoryNodeKind.turning => '转折',
        StoryNodeKind.ending => '结束',
      };

  static const Set<String> tagNames = {
    'opening',
    'scene',
    'turning',
    'ending',
  };

  static StoryNodeKind fromTags(List<String> tags) {
    for (final kind in StoryNodeKind.values) {
      if (tags.contains(kind.name)) return kind;
    }
    return StoryNodeKind.scene;
  }

  /// Replaces any previous kind tag; preserves unrelated tags.
  static List<String> apply(List<String> tags, StoryNodeKind kind) {
    return [
      ...tags.where((t) => !tagNames.contains(t)),
      kind.name,
    ];
  }
}
