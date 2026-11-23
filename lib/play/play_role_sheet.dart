import 'dart:io';

import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Asks which cast member the player role-plays in this slot.
///
/// Returns the chosen [CastMember.id], or null when dismissed. The choice is
/// locked into the save slot and never asked again for that playthrough.
Future<String?> showPlayRoleSheet(
  BuildContext context, {
  required Project project,
  String? projectDir,
}) {
  return showAppSheet<String>(
    context: context,
    size: AppSheetSize.half,
    builder: (ctx) {
      final strings = ctx.strings;
      return AppSheetScrollBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(strings.playRoleTitle, role: AppTextRole.title),
                const SizedBox(height: AppTheme.spaceXs),
                AppText(strings.playRoleHint, role: AppTextRole.caption),
              ],
            ),
          ),
          AppListTileStack(
            tiles: [
              for (final member in project.cast)
                _roleTile(
                  ctx,
                  project: project,
                  member: member,
                  projectDir: projectDir,
                ),
            ],
          ),
        ],
      );
    },
  );
}

AppListTile _roleTile(
  BuildContext context, {
  required Project project,
  required CastMember member,
  required String? projectDir,
}) {
  final strings = context.strings;
  final summary = member.summary.trim().isNotEmpty
      ? member.summary.trim()
      : (member.personality.trim().isNotEmpty
          ? member.personality.trim()
          : strings.castNoSummary);
  final subtitle =
      member.isProtagonist ? strings.castProtagonist(summary) : summary;
  return AppListTile(
    title: member.name,
    subtitle: subtitle,
    leading: _RoleAvatar(
      project: project,
      member: member,
      projectDir: projectDir,
    ),
    trailing: const AppForwardIcon(),
    onTap: () {
      AppLog.instance.info('选择扮演：${member.name}', tag: 'play.role');
      Navigator.of(context).pop(member.id);
    },
  );
}

class _RoleAvatar extends StatelessWidget {
  const _RoleAvatar({
    required this.project,
    required this.member,
    required this.projectDir,
  });

  final Project project;
  final CastMember member;
  final String? projectDir;

  static const double _size = 40;

  File? get _file {
    final dir = projectDir;
    final assetId = member.avatarAssetId?.trim();
    if (dir == null || assetId == null || assetId.isEmpty) return null;
    return ProjectAssetFiles.tryFile(
      projectDir: dir,
      asset: project.assetById(assetId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final icon = Icon(
      member.isProtagonist ? Icons.star_outline : Icons.person_outline,
      size: AppListTile.iconSize,
    );
    if (file == null) return icon;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.spaceXs),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Image.file(
          file,
          key: ValueKey(
            '${file.path}-${file.lastModifiedSync().millisecondsSinceEpoch}',
          ),
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => icon,
        ),
      ),
    );
  }
}
