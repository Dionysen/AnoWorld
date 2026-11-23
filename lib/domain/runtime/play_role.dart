import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';

/// Who the player is in one VN session.
///
/// Chosen when a new slot starts and then locked for that slot. Drives which
/// cast member answers to the player, which member fills `{{char}}`, and how
/// the dialogue box labels the player's own lines.
class PlayRole {
  const PlayRole({this.playerCastId, this.aliases = const <String>[]});

  /// [CastMember.id] the player role-plays; null when the story has no cast.
  final String? playerCastId;

  /// Extra player-facing names (Persona name, 我, 玩家 …) besides the cast
  /// member's own name and aliases.
  final List<String> aliases;

  static const PlayRole none = PlayRole();

  CastMember? playerIn(Project project) {
    final id = playerCastId;
    if (id == null || id.isEmpty) return null;
    return project.castById(id);
  }

  /// Member that owns `{{char}}` / the scene's focus.
  ///
  /// Prefers the flagged protagonist; when the player *is* the protagonist,
  /// the first other member takes the focus so the two never collide.
  CastMember? focusIn(Project project) {
    final player = playerIn(project);
    final lead = project.protagonist ??
        (project.cast.isEmpty ? null : project.cast.first);
    if (lead != null && lead.id != player?.id) return lead;
    for (final member in project.cast) {
      if (member.id != player?.id) return member;
    }
    return null;
  }

  /// Every string that should read as "the player speaking".
  List<String> playerAliasesIn(Project project) {
    final player = playerIn(project);
    return <String>[
      if (player != null && player.name.trim().isNotEmpty) player.name,
      if (player != null)
        for (final alias in player.aliases)
          if (alias.trim().isNotEmpty) alias,
      for (final alias in aliases)
        if (alias.trim().isNotEmpty) alias,
    ];
  }

  /// Display label for the player's own dialogue.
  String labelIn(Project project, {required String fallback}) {
    final player = playerIn(project);
    final name = player?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    final first = playerAliasesIn(project).firstOrNull?.trim();
    return first == null || first.isEmpty ? fallback : first;
  }

  /// Whether [speaker] names the player rather than a cast member.
  bool speaksAsPlayer(String speaker, Project project) {
    final needle = normalizeCastName(speaker);
    if (needle.isEmpty) return false;
    for (final alias in playerAliasesIn(project)) {
      if (normalizeCastName(alias) == needle) return true;
    }
    return false;
  }
}
