/// Which story layer the create assistant is editing this turn.
enum CreateAssistantTarget {
  graph,
  world,
  cast;

  String get wireName => name;

  static CreateAssistantTarget parse(String? raw) {
    return switch (raw) {
      'world' => CreateAssistantTarget.world,
      'cast' => CreateAssistantTarget.cast,
      _ => CreateAssistantTarget.graph,
    };
  }

  /// Read tools every target may use: cross-layer context is what makes the
  /// proposal consistent, and reading cannot corrupt the story.
  static const List<String> readTools = <String>[
    'project.read_summary',
    'main.read_graph',
    'world.list_entries',
    'world.read_entry',
    'cast.list_members',
    'cast.read_member',
  ];

  /// Write tools allowed for this target; only its own layer can be changed.
  List<String> get writeTools => switch (this) {
        CreateAssistantTarget.graph => const <String>[
            'main.replace',
            'main.patch',
          ],
        CreateAssistantTarget.world => const <String>['world.patch'],
        CreateAssistantTarget.cast => const <String>['cast.patch'],
      };

  /// Tools the agent may call for this target (allowlist).
  List<String> get toolAllowlist => <String>[...readTools, ...writeTools];
}
