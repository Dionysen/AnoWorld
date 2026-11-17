import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:flutter/material.dart';

/// Asks how to play this story. Returns null if dismissed.
Future<PlayViewMode?> showPlayModeSheet(BuildContext context) {
  return showAppSheet<PlayViewMode>(
    context: context,
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceMd,
            ),
            child: AppText('怎么玩', role: AppTextRole.title),
          ),
          AppListTile(
            icon: Icons.auto_stories_outlined,
            title: '视觉小说',
            subtitle: '舞台与对白框，点一下往下看',
            onTap: () => Navigator.of(ctx).pop(PlayViewMode.visualNovel),
          ),
          AppListTile(
            icon: Icons.chat_bubble_outline,
            title: '聊天',
            subtitle: '气泡对话，打字或点选项继续',
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop(PlayViewMode.chat),
          ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
      );
    },
  );
}
