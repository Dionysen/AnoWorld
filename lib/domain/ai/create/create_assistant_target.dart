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

  /// Tools the agent may call for this target (allowlist).
  List<String> get toolAllowlist => switch (this) {
        CreateAssistantTarget.graph => const [
            'main.read_graph',
            'main.generate_graph',
            'main.patch_graph',
          ],
        CreateAssistantTarget.world => const [
            'world.list_entries',
            'world.read_entry',
            'world.patch_propose',
          ],
        CreateAssistantTarget.cast => const [
            'cast.list_members',
            'cast.read_member',
            'cast.patch_propose',
          ],
      };
}
