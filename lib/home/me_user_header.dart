import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_person_avatar.dart';
import 'package:flutter/material.dart';

/// Current-user row on the Me tab — same metrics as settings [AppListTile].
class MeUserHeader extends StatelessWidget {
  const MeUserHeader({
    super.key,
    required this.persona,
    required this.onTap,
  });

  final UserPersona persona;
  final VoidCallback onTap;

  /// Matches the persona list leading avatar in settings.
  static const double avatarSize = 40;

  @override
  Widget build(BuildContext context) {
    final desc = persona.description.trim();
    return AppListTile(
      title: persona.name,
      subtitle: desc.isEmpty ? null : desc,
      leading: AppPersonAvatar(
        size: avatarSize,
        semanticLabel: persona.name,
      ),
      onTap: onTap,
      trailing: const AppForwardIcon(),
      showDivider: false,
    );
  }
}
