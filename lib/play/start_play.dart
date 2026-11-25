import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:anoworld/play/play_mode_sheet.dart';
import 'package:anoworld/play/play_role_sheet.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:flutter/material.dart';

/// Starts a brand-new play slot: pick a mode, then (for visual novels) the
/// character the player role-plays.
///
/// Visual novel requires at least one cast member; otherwise the flow stops
/// with a toast. Returns after the session closes so callers can refresh.
Future<void> startNewPlay(
  BuildContext context,
  Project project, {
  bool replace = false,
}) async {
  final mode = await showPlayModeSheet(context);
  if (!context.mounted || mode == null) return;

  String? playerCastId;
  if (mode == PlayViewMode.visualNovel) {
    if (project.cast.isEmpty) {
      AppLog.instance.warning('视觉小说缺少可扮演角色', tag: 'play.start');
      showAppToast(context, context.strings.playNeedsCast);
      return;
    }
    if (project.cast.length == 1) {
      playerCastId = project.cast.first.id;
    } else {
      final dir = await AppScope.projectsOf(
        context,
      ).directoryFor(project.meta.id);
      if (!context.mounted) return;
      final chosen = await showPlayRoleSheet(
        context,
        project: project,
        projectDir: dir,
      );
      if (!context.mounted || chosen == null) return;
      playerCastId = chosen;
    }
  }

  AppLog.instance.info(
    '开新局：${project.meta.title}（${mode.name}）',
    tag: 'play.start',
  );
  final page = PlaySessionPage(
    project: project,
    mode: mode,
    resumeSave: false,
    playerCastId: playerCastId,
  );
  // Playing is a full-window experience: a visual-novel stage or chat screen
  // must not be squeezed into a master-detail column.
  if (replace) {
    // Only the staged-create flow replaces, and that page is always pushed on
    // the root navigator, so replacing the root's top route is safe.
    await Navigator.of(context, rootNavigator: true).pushReplacement(
      AppSlidePageRoute<void>(builder: (_) => page),
    );
  } else {
    await pushAppSlide(context, page, fullscreen: true);
  }
}
