import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_detail_entry.dart';
import 'app_expandable_text.dart';
import 'app_icon_button.dart';
import 'app_list_hairline.dart';
import 'app_list_tile.dart';
import 'app_page_gutter.dart';
import 'app_text.dart';
import 'app_toast.dart';

/// Flat story-detail block: section header + hairline-separated entries.
///
/// Long sections only mount the first [initialVisibleCount] rows until the
/// user taps「还有 n 条」. Each row body stays collapsed to [previewLines]
/// until expanded.
class AppDetailSection extends StatefulWidget {
  const AppDetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.entries,
    required this.onEdit,
    this.subtitle,
    this.emptyHint,
    this.previewLines = 3,
    this.initialVisibleCount = 8,
  });

  final String title;
  final IconData icon;
  final List<AppDetailEntry> entries;
  final VoidCallback onEdit;

  /// Caption under [title] (counts / size); hidden when null or blank.
  final String? subtitle;
  final String? emptyHint;
  final int previewLines;

  /// How many entry rows to build before「还有 n 条」.
  final int initialVisibleCount;

  @override
  State<AppDetailSection> createState() => _AppDetailSectionState();
}

class _AppDetailSectionState extends State<AppDetailSection> {
  bool _showAll = false;

  @override
  void didUpdateWidget(covariant AppDetailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries) &&
        oldWidget.entries.length != widget.entries.length) {
      _showAll = false;
    }
  }

  List<AppDetailEntry> get _visibleEntries {
    return widget.entries
        .where(
          (e) =>
              e.title.trim().isNotEmpty ||
              e.body.trim().isNotEmpty ||
              e.tags.isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visibleEntries;
    final isEmpty = visible.isEmpty;
    final emptyHint = widget.emptyHint ?? context.ui.emptyContent;
    final subtitle = widget.subtitle?.trim() ?? '';
    final cap = widget.initialVisibleCount < 1 ? 1 : widget.initialVisibleCount;
    final capped = !_showAll && visible.length > cap;
    final shown = capped ? visible.take(cap).toList(growable: false) : visible;
    final hiddenCount = capped ? visible.length - shown.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageGutter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 112;
              final edit = AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: context.ui.edit,
                size: compact ? 28 : 36,
                iconSize: compact ? 16 : 20,
                onPressed: widget.onEdit,
              );
              // Icon centers on the title + subtitle block; the edit button
              // stays top-aligned with the title.
              final heading = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(widget.icon, size: 20, color: scheme.primary),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppText(
                                widget.title,
                                role: AppTextRole.subtitle,
                                maxLines: 1,
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: AppTheme.spaceXs),
                                AppText(
                                  subtitle,
                                  role: AppTextRole.caption,
                                  maxLines: 2,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) edit,
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: AppTheme.spaceXs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: edit,
                    ),
                  ],
                );
              }
              return heading;
            },
          ),
        ),
        if (isEmpty)
          AppPageGutter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppTheme.spaceSm,
                bottom: AppTheme.spaceInline,
              ),
              child: AppText(emptyHint, role: AppTextRole.caption),
            ),
          )
        else ...[
          for (var i = 0; i < shown.length; i++)
            _DetailEntryRow(
              key: ValueKey<String>('$i\u0000${shown[i].title}'),
              entry: shown[i],
              previewLines: widget.previewLines,
            ),
          if (hiddenCount > 0)
            AppListTile(
              title: context.ui.moreEntries(hiddenCount),
              onTap: () => setState(() => _showAll = true),
            ),
        ],
      ],
    );
  }
}

class _DetailEntryRow extends StatefulWidget {
  const _DetailEntryRow({
    super.key,
    required this.entry,
    required this.previewLines,
  });

  final AppDetailEntry entry;
  final int previewLines;

  @override
  State<_DetailEntryRow> createState() => _DetailEntryRowState();
}

class _DetailEntryRowState extends State<_DetailEntryRow> {
  bool _expanded = false;

  /// ~40 glyphs/line at typical phone widths for compact body.
  static const int _glyphsPerPreviewLine = 40;

  @override
  void didUpdateWidget(covariant _DetailEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.title != widget.entry.title ||
        oldWidget.entry.body != widget.entry.body ||
        !_sameTags(oldWidget.entry.tags, widget.entry.tags)) {
      _expanded = false;
    }
  }

  bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Cheap overflow guess — avoids post-frame [TextPainter] + setState storms
  /// when a story detail page first mounts dozens of entries.
  bool _bodyLikelyOverflows(String body) {
    if (body.isEmpty) return false;
    var lines = 1;
    for (var i = 0; i < body.length; i++) {
      if (body.codeUnitAt(i) == 0x0A) lines++;
      if (lines > widget.previewLines) return true;
    }
    return body.length > widget.previewLines * _glyphsPerPreviewLine;
  }

  /// Truncate for collapsed layout so huge bodies are not measured fully.
  String _previewBody(String body) {
    final maxChars = widget.previewLines * _glyphsPerPreviewLine;
    var lines = 0;
    var end = body.length;
    for (var i = 0; i < body.length; i++) {
      if (body.codeUnitAt(i) == 0x0A) {
        lines++;
        if (lines >= widget.previewLines) {
          end = i;
          break;
        }
      }
      if (i + 1 >= maxChars) {
        end = i + 1;
        break;
      }
    }
    if (end >= body.length) return body;
    return body.substring(0, end);
  }

  Future<void> _copy() async {
    final ui = context.ui;
    final text = widget.entry.clipboardText(ui.listSeparator);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppToast(context, ui.copiedEntry(widget.entry.copyLabel(ui.entry)));
  }

  static const double _entryActionSize = 28;
  static const double _entryActionIcon = 16;

  List<Widget> _entryActions({
    required AppLocalizations ui,
    required bool hasCopy,
    required bool canExpand,
  }) {
    return <Widget>[
      if (hasCopy)
        AppIconButton(
          icon: Icons.copy_outlined,
          tooltip: ui.copy,
          size: _entryActionSize,
          iconSize: _entryActionIcon,
          onPressed: _copy,
        ),
      if (canExpand)
        AppIconButton(
          icon: _expanded ? Icons.expand_less : Icons.expand_more,
          tooltip: _expanded ? ui.collapse : ui.expand,
          size: _entryActionSize,
          iconSize: _entryActionIcon,
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
    ];
  }

  Widget _actionCluster(List<Widget> actions, double maxWidth) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final horizontal = actions.length * _entryActionSize;
    if (maxWidth >= horizontal) {
      return Row(mainAxisSize: MainAxisSize.min, children: actions);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: actions,
    );
  }

  double _actionClusterWidth(List<Widget> actions, double maxWidth) {
    if (actions.isEmpty) return 0;
    final horizontal = actions.length * _entryActionSize;
    return maxWidth >= horizontal ? horizontal : _entryActionSize;
  }

  Widget _entryHeaderRow({
    required String title,
    required List<Widget> actions,
    required double maxWidth,
  }) {
    if (actions.isEmpty) {
      return AppText(title, role: AppTextRole.compactLabel, maxLines: 1);
    }

    final cluster = _actionCluster(actions, maxWidth);
    final clusterWidth = _actionClusterWidth(actions, maxWidth);
    final fitsBesideTitle =
        title.isEmpty || maxWidth >= clusterWidth + AppTheme.spaceSm + 24;

    if (!fitsBesideTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty)
            AppText(title, role: AppTextRole.compactLabel, maxLines: 2),
          if (title.isNotEmpty) const SizedBox(height: AppTheme.spaceXs),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: cluster,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Expanded(
            child: AppText(
              title,
              role: AppTextRole.compactLabel,
              maxLines: 1,
            ),
          )
        else
          const Spacer(),
        cluster,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.entry.title.trim();
    final body = widget.entry.body.trim();
    final hasCopy = widget.entry.hasClipboardText;
    final canExpand = _bodyLikelyOverflows(body);
    final showFull = _expanded || !canExpand;
    final displayBody = showFull ? body : _previewBody(body);
    final actions = _entryActions(
      ui: context.ui,
      hasCopy: hasCopy,
      canExpand: canExpand,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageGutter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceInline),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty || actions.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return _entryHeaderRow(
                        title: title,
                        actions: actions,
                        maxWidth: constraints.maxWidth,
                      );
                    },
                  ),
                if (widget.entry.tags.isNotEmpty) ...[
                  if (title.isNotEmpty || actions.isNotEmpty)
                    const SizedBox(height: AppTheme.spaceXs),
                  _EntryTagWrap(tags: widget.entry.tags),
                ],
                if (body.isNotEmpty) ...[
                  if (title.isNotEmpty ||
                      widget.entry.tags.isNotEmpty ||
                      actions.isNotEmpty)
                    const SizedBox(height: AppTheme.spaceXs),
                  AppExpandableText(
                    text: displayBody,
                    expanded: showFull,
                    previewLines: widget.previewLines,
                    role: AppTextRole.compactBody,
                  ),
                ],
              ],
            ),
          ),
        ),
        const AppListHairline(),
      ],
    );
  }
}

class _EntryTagWrap extends StatelessWidget {
  const _EntryTagWrap({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tagFill = Color.alphaBlend(
      scheme.primary.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.1 : 0.07,
      ),
      scheme.surface,
    );
    final tagShape = AppUiTokens.of(context).shape(
      side: BorderSide(color: scheme.primary.withValues(alpha: 0.16)),
    );

    return Wrap(
      spacing: AppTheme.spaceXs,
      runSpacing: AppTheme.spaceXs,
      children: [
        for (final tag in tags)
          if (tag.trim().isNotEmpty)
            DecoratedBox(
              decoration: ShapeDecoration(
                color: tagFill,
                shape: tagShape,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: AppTheme.spaceXs,
                ),
                child: AppText(tag.trim(), role: AppTextRole.compactTag),
              ),
            ),
      ],
    );
  }
}
