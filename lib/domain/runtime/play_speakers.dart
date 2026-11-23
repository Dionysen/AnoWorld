import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/play_role.dart';

/// Leading `名字：` / `Name:` label, if any.
final RegExp _speakerLabelPattern = RegExp(r'^([^：:\n]{1,24})[：:]\s*');

String? dialogueSpeakerLabel(String text) {
  final trimmed = text.trimLeft();
  final match = _speakerLabelPattern.firstMatch(trimmed);
  if (match == null) return null;
  final label = match.group(1)!.trim();
  if (label.isEmpty || RegExp(r'^\d').hasMatch(label)) return null;
  return label;
}

/// Strips a leading `名字：` / `Name:` label from dialogue body text.
String stripDialogueSpeakerLabel(String text) {
  final trimmed = text.trimLeft();
  final match = _speakerLabelPattern.firstMatch(trimmed);
  if (match == null) return text;
  final label = match.group(1)!.trim();
  if (label.isEmpty || RegExp(r'^\d').hasMatch(label)) return text;
  return trimmed.substring(match.end);
}

const Set<String> _narratorNames = <String>{
  '旁白',
  '叙述',
  'narrator',
  'narration',
  'system',
  '系统',
};

/// Whether [speaker] is a narration marker (empty / 旁白 / narrator …).
bool isNarratorSpeaker(String speaker) {
  final normalized = normalizeCastName(speaker).toLowerCase();
  return normalized.isEmpty || _narratorNames.contains(normalized);
}

/// Maps a model-supplied speaker string to a defined cast id, or narration.
///
/// Strict contract: a line is spoken only by a defined [CastMember] (including
/// the player's own member). Anything else becomes narration so no bare name
/// ever reaches the stage.
///
/// [recognized] is false when the speaker is narration or an unknown name.
({String? castId, bool recognized}) resolveDialogueSpeaker({
  required String speaker,
  required Project project,
  required PlayRole role,
}) {
  if (isNarratorSpeaker(speaker)) {
    return (castId: null, recognized: false);
  }
  final member = castMemberForSpeaker(project.cast, speaker);
  if (member != null) {
    return (castId: member.id, recognized: true);
  }
  if (role.speaksAsPlayer(speaker, project)) {
    final playerId = role.playerIn(project)?.id;
    if (playerId != null) {
      return (castId: playerId, recognized: true);
    }
  }
  return (castId: null, recognized: false);
}
