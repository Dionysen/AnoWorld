import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:anoworld/home/create_assistant_story_scope.dart';
import 'package:flutter/material.dart';

/// Edits the card provenance kept on a story (author, version, tags, notes).
class StoryCardMetaPage extends StatefulWidget {
  const StoryCardMetaPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<StoryCardMetaPage> createState() => _StoryCardMetaPageState();
}

class _StoryCardMetaPageState extends State<StoryCardMetaPage>
    with CreateAssistantStoryScope<StoryCardMetaPage> {
  @override
  String get assistantStoryId => widget.projectId;

  Project? _project;
  Object? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null && _loading) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await AppScope.projectsOf(context).open(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
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

  Future<void> _save(StoryCardMeta card) async {
    final current = _project;
    if (current == null) return;
    setState(() {
      _project = current.copyWith(
        meta: current.meta.copyWith(card: card),
      );
    });
    try {
      final saved = await saveProjectMerged(
        AppScope.projectsOf(context),
        widget.projectId,
        (latest) => latest.copyWith(meta: latest.meta.copyWith(card: card)),
      );
      AppLog.instance.info('更新卡片信息', tag: 'project.card');
      if (!mounted) return;
      setState(() => _project = saved);
    } catch (error, stack) {
      AppLog.instance.error(
        '更新卡片信息失败',
        tag: 'project.card',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _project = current);
    }
  }

  static List<String> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[,，、]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  static String _joinTags(List<String> tags) => tags.join('，');

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final project = _project;
    final card = project?.meta.card ?? StoryCardMeta.empty;
    return AppPage(
      title: strings.cardInfoEditTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          if (_loading)
            AppPageGutter(
              child: AppText(strings.loading, role: AppTextRole.caption),
            )
          else if (_error != null)
            AppPageGutter(
              child: AppEmptyState(
                message: strings.openStoryFailed,
                detail: _error.toString(),
                action: AppButton(
                  label: strings.retry,
                  onPressed: _load,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            )
          else ...[
            AppSectionHeader(strings.cardInfoTitle, gutter: true),
            const SizedBox(height: AppTheme.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextEditTile(
                  title: strings.cardInfoCreator,
                  icon: Icons.person_outline,
                  value: card.creator,
                  onSubmitted: (value) => _save(card.copyWith(creator: value)),
                ),
                AppTextEditTile(
                  title: strings.cardInfoVersion,
                  icon: Icons.tag_outlined,
                  value: card.version,
                  onSubmitted: (value) => _save(card.copyWith(version: value)),
                ),
                AppTextEditTile(
                  title: strings.cardInfoTags,
                  subtitle: strings.cardInfoTagsHint,
                  icon: Icons.sell_outlined,
                  value: _joinTags(card.tags),
                  onSubmitted: (value) =>
                      _save(card.copyWith(tags: _parseTags(value))),
                ),
                AppTextEditTile(
                  title: strings.cardInfoCreatedAt,
                  icon: Icons.event_outlined,
                  value: card.createdAt,
                  hint: strings.cardInfoCreatedAtHint,
                  onSubmitted: (value) =>
                      _save(card.copyWith(createdAt: value.trim())),
                ),
                AppTextEditTile(
                  title: strings.cardInfoModifiedAt,
                  icon: Icons.update_outlined,
                  value: card.modifiedAt,
                  hint: strings.cardInfoModifiedAtHint,
                  onSubmitted: (value) =>
                      _save(card.copyWith(modifiedAt: value.trim())),
                ),
                AppTextEditTile(
                  title: strings.cardInfoCreatorNotes,
                  icon: Icons.sticky_note_2_outlined,
                  value: card.creatorNotes,
                  hint: strings.cardInfoCreatorNotesHint,
                  minLines: 3,
                  maxLines: 8,
                  showDivider: false,
                  onSubmitted: (value) =>
                      _save(card.copyWith(creatorNotes: value)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
