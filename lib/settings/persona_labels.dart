import 'package:anoworld/foundation/persona/user_persona.dart';

/// Row subtitle for an identity: its short description, if any.
String? personaSubtitle(UserPersona persona) {
  final desc = persona.description.trim();
  if (desc.isEmpty) return null;
  return desc.length > 36 ? '${desc.substring(0, 36)}…' : desc;
}
