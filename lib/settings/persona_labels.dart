import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';

/// Row subtitle for an identity: its short description, marked when it is the
/// one currently in use.
String? personaSubtitle(
  AppStrings strings,
  UserPersona persona,
  String? activeId,
) {
  final desc = persona.description.trim();
  final inUse = persona.id == activeId;
  if (desc.isEmpty) return inUse ? strings.personaInUse : null;
  final short = desc.length > 36 ? '${desc.substring(0, 36)}…' : desc;
  return inUse ? strings.personaInUseWith(short) : short;
}
