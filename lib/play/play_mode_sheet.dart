import 'package:anoworld/app/l10n/app_strings.dart';
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
      final strings = ctx.strings;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceMd,
            ),
            child: AppText(strings.howToPlay, role: AppTextRole.title),
          ),
          AppListTile(
            icon: Icons.auto_stories_outlined,
            title: strings.kindVisualNovel,
            subtitle: strings.visualNovelModeHint,
            onTap: () => Navigator.of(ctx).pop(PlayViewMode.visualNovel),
          ),
          AppListTile(
            icon: Icons.chat_bubble_outline,
            title: strings.kindChat,
            subtitle: strings.chatModeHint,
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop(PlayViewMode.chat),
          ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
      );
    },
  );
}
