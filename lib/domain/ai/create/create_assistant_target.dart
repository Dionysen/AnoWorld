/// Which story layer the create assistant is editing this turn.
///
/// [all] is the cross-layer mode: every write tool is mounted, and the loop
/// collects proposals from several layers into one confirmation batch.
enum CreateAssistantTarget {
  graph,
  world,
  cast,
  all;

  String get wireName => name;

  static CreateAssistantTarget parse(String? raw) {
    return switch (raw) {
      'world' => CreateAssistantTarget.world,
      'cast' => CreateAssistantTarget.cast,
      'all' => CreateAssistantTarget.all,
      _ => CreateAssistantTarget.graph,
    };
  }

  /// Read tools every target may use: cross-layer context is what makes the
  /// proposal consistent, and reading cannot corrupt the story.
  static const List<String> readTools = <String>[
    'project.read_summary',
    'main.read_graph',
    'main.list_nodes',
    'main.get_node',
    'world.list_entries',
    'world.read_entry',
    'cast.list_members',
    'cast.read_member',
    'plot.list_elements',
  ];

  /// Write tools allowed for this target; only its own layer can be changed,
  /// except [all], which may change every layer in one turn.
  List<String> get writeTools => switch (this) {
    CreateAssistantTarget.graph => const <String>[
      'main.replace',
      'main.patch',
      'plot.select',
    ],
    CreateAssistantTarget.world => const <String>['world.patch'],
    CreateAssistantTarget.cast => const <String>['cast.patch'],
    CreateAssistantTarget.all => const <String>[
      'main.replace',
      'main.patch',
      'world.patch',
      'cast.patch',
      'plot.select',
    ],
  };

  /// Tools the agent may call for this target (allowlist).
  List<String> get toolAllowlist => <String>[...readTools, ...writeTools];
}
