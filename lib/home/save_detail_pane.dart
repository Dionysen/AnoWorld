import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/app/project_change_watcher.dart';
import 'package:anoworld/data/project/project_cover_files.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_image.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/save_time_label.dart';
import 'package:flutter/material.dart';

/// Detail column for the save selected in the wide-window sessions list.
///
/// Playing itself is a full-window stage, so this column keeps the save's own
/// summary — cover, story, mode, last played — and hands 「继续游玩」 back to the
/// tab, which opens the session on the root navigator.
class SaveDetailPane extends StatefulWidget {
  const SaveDetailPane({
    super.key,
    required this.slot,
    required this.projectId,
    required this.onResume,
    required this.onOpenStory,
    required this.onDelete,
  });

  final SaveSlot slot;
  final String projectId;

  /// Opens the play session full-screen for this save.
  final VoidCallback onResume;

  /// Opens the story page inside this column.
  final VoidCallback onOpenStory;

  final VoidCallback onDelete;

  @override
  State<SaveDetailPane> createState() => _SaveDetailPaneState();
}

class _SaveDetailPaneState extends State<SaveDetailPane>
    with ProjectChangeWatcher<SaveDetailPane> {
  Project? _project;
  String? _coverPath;
  Object? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _project == null && _error == null) {
      unawaited(_load());
    }
  }

  @override
  String get watchedProjectId => widget.projectId;

  @override
  void reloadAfterExternalWrite() {
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final projects = AppScope.projectsOf(context);
      final project = await projects.open(widget.projectId);
      final dir = await projects.directoryFor(widget.projectId);
      final relative = dir == null
          ? null
          : await ProjectCoverFiles.resolveExistingRelative(
              dir,
              project.meta.coverPath,
            );
      if (!mounted) return;
      setState(() {
        _project = project;
        _coverPath = relative == null || dir == null
            ? null
            : ProjectCoverFiles.absolutePath(dir, relative);
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final project = _project;
    if (_loading) {
      return Center(
        child: AppText(strings.loading, role: AppTextRole.caption),
      );
    }
    if (project == null || _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: AppEmptyState(
            message: strings.openStoryFailed,
            detail: _error?.toString(),
            action: AppButton(
              label: strings.retry,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                setState(() => _loading = true);
                unawaited(_load());
              },
            ),
          ),
        ),
      );
    }

    final title = project.meta.title.trim().isEmpty
        ? strings.untitledStory
        : project.meta.title.trim();
    final kind = widget.slot.mode == PlayViewMode.chat
        ? strings.kindChat
        : strings.kindVisualNovel;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square 16:9 cover flush to the pane edges, like the story page.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _SaveCover(title: title, path: _coverPath),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppText(
                        title,
                        role: AppTextRole.title,
                        maxLines: 2,
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.delete_outline,
                      tooltip: strings.delete,
                      danger: true,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXs),
                AppText(
                  strings.lastPlayed(
                    kind,
                    saveTimeLabel(context, widget.slot.savedAt),
                  ),
                  role: AppTextRole.caption,
                ),
                const SizedBox(height: AppTheme.spaceLg),
                AppButton(
                  label: strings.resumePlay,
                  expanded: true,
                  onPressed: widget.onResume,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                AppButton(
                  label: strings.openStory,
                  variant: AppButtonVariant.secondary,
                  expanded: true,
                  onPressed: widget.onOpenStory,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Story cover with the first character of the title as placeholder.
class _SaveCover extends StatelessWidget {
  const _SaveCover({required this.title, required this.path});

  final String title;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = title.isEmpty ? '?' : title.characters.first;
    final placeholder = ColoredBox(
      color: scheme.primary.withValues(alpha: 0.16),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 48,
          ),
        ),
      ),
    );
    final path = this.path;
    if (path == null) return placeholder;
    return AppImage(path: path, fallback: placeholder);
  }
}
