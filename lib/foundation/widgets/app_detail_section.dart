import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_detail_entry.dart';
import 'app_disclosure_icon.dart';
import 'app_expandable_text.dart';
import 'app_icon_button.dart';
import 'app_list_hairline.dart';
import 'app_list_tile.dart';
import 'app_page_gutter.dart';
import 'app_text.dart';
import 'app_toast.dart';

/// Collapsible story-detail block: [AppListTile] header + optional entries.
///
/// Tap the header to expand; [onEdit] opens the section editor without
/// expanding. Long sections only mount the first [initialVisibleCount] rows
/// until「还有 n 条」; each row body stays collapsed to [previewLines].
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
    this.initiallyExpanded = false,
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

  /// Whether the section body starts open. Defaults to collapsed.
  final bool initiallyExpanded;

  @override
  State<AppDetailSection> createState() => _AppDetailSectionState();
}

class _AppDetailSectionState extends State<AppDetailSection> {
  bool _showAll = false;
  late bool _expanded = widget.initiallyExpanded;

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

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
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
        AppListTile(
          title: widget.title,
          subtitle: subtitle.isEmpty ? null : subtitle,
          icon: widget.icon,
          selected: _expanded,
          trailing: AppDisclosureIcon(expanded: _expanded),
          onEdit: widget.onEdit,
          onTap: _toggleExpanded,
          showDivider: !_expanded,
        ),
        if (_expanded) ...[
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
                showDivider: false,
              ),
          ],
          const AppListHairline(),
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

  Widget _entryTitleAndTags({
    required String title,
    required List<String> tags,
  }) {
    final chips = <Widget>[
      for (final tag in tags)
        if (tag.trim().isNotEmpty) _EntryTagChip(label: tag.trim()),
    ];
    if (title.isEmpty && chips.isEmpty) return const SizedBox.shrink();
    if (chips.isEmpty) {
      return AppText(title, role: AppTextRole.compactLabel, maxLines: 1);
    }
    // Title then chips on the same run; overflow wraps under the title.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppTheme.spaceXs,
      runSpacing: AppTheme.spaceXs,
      children: [
        if (title.isNotEmpty)
          AppText(title, role: AppTextRole.compactLabel, maxLines: 1),
        ...chips,
      ],
    );
  }

  Widget _entryHeaderRow({
    required String title,
    required List<String> tags,
    required List<Widget> actions,
    required double maxWidth,
  }) {
    final heading = _entryTitleAndTags(title: title, tags: tags);
    if (actions.isEmpty) return heading;

    final cluster = _actionCluster(actions, maxWidth);
    final clusterWidth = _actionClusterWidth(actions, maxWidth);
    final hasHeading = title.isNotEmpty || tags.isNotEmpty;
    final fitsBesideTitle =
        !hasHeading || maxWidth >= clusterWidth + AppTheme.spaceSm + 24;

    if (!fitsBesideTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeading) heading,
          if (hasHeading) const SizedBox(height: AppTheme.spaceXs),
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
        if (hasHeading)
          Expanded(child: heading)
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
    final tags = widget.entry.tags;
    final hasCopy = widget.entry.hasClipboardText;
    final canExpand = _bodyLikelyOverflows(body);
    final showFull = _expanded || !canExpand;
    final displayBody = showFull ? body : _previewBody(body);
    final actions = _entryActions(
      ui: context.ui,
      hasCopy: hasCopy,
      canExpand: canExpand,
    );
    final hasHeading = title.isNotEmpty || tags.isNotEmpty || actions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageGutter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceInline),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasHeading)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return _entryHeaderRow(
                        title: title,
                        tags: tags,
                        actions: actions,
                        maxWidth: constraints.maxWidth,
                      );
                    },
                  ),
                if (body.isNotEmpty) ...[
                  if (hasHeading) const SizedBox(height: AppTheme.spaceXs),
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

class _EntryTagChip extends StatelessWidget {
  const _EntryTagChip({required this.label});

  final String label;

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

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tagFill,
        shape: tagShape,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm,
          vertical: AppTheme.spaceXs,
        ),
        child: AppText(label, role: AppTextRole.compactTag),
      ),
    );
  }
}
