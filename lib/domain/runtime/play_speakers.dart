import 'package:anoworld/domain/models/cast.dart';

/// Speaker id for player lines (composer / explicit User aliases).
const String kPlayUserSpeakerId = '__user__';

final RegExp _speakerLabelPattern = RegExp(r'^([^：:\n]{1,24})[：:]\s*');

/// Leading `名字：` / `Name:` label, if any.
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

/// Whether [speakerId] refers to a cast member (by id or exact name).
bool speakerIsCastMember(String? speakerId, List<CastMember> cast) {
  if (speakerId == null || speakerId.isEmpty) return false;
  if (speakerId == kPlayUserSpeakerId) return false;
  for (final member in cast) {
    if (member.id == speakerId || member.name == speakerId) return true;
  }
  return false;
}

/// Player speech: explicit user id, known aliases, or any non-cast speaker
/// (story nicknames like「老公」when User is the husband).
bool speakerIsPlayer({
  required String? speakerId,
  required List<CastMember> cast,
  List<String> userAliases = const <String>[],
}) {
  if (speakerId == null || speakerId.isEmpty) return false;
  if (speakerId == kPlayUserSpeakerId) return true;
  final lower = speakerId.toLowerCase();
  for (final alias in userAliases) {
    final a = alias.trim();
    if (a.isEmpty) continue;
    if (a == speakerId || a.toLowerCase() == lower) return true;
  }
  return !speakerIsCastMember(speakerId, cast);
}
