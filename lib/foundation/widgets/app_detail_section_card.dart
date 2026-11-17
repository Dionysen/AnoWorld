import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_detail_entry.dart';
import 'app_expandable_text.dart';
import 'app_icon_button.dart';
import 'app_surface.dart';
import 'app_text.dart';

/// Structured story-detail block: titled entries (worldbook-style), edit section.
class AppDetailSectionCard extends StatelessWidget {
  const AppDetailSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.entries,
    required this.onEdit,
    this.emptyHint,
    this.previewLines = 3,
  });

  final String title;
  final IconData icon;
  final List<AppDetailEntry> entries;
  final VoidCallback onEdit;
  final String? emptyHint;
  final int previewLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = entries
        .where((e) =>
            e.title.trim().isNotEmpty ||
            e.body.trim().isNotEmpty ||
            e.tags.isNotEmpty)
        .toList(growable: false);
    final isEmpty = visible.isEmpty;
    final emptyHint = this.emptyHint ?? '这里还没有内容';

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 112;
              final edit = AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: '编辑',
                size: compact ? 28 : 36,
                iconSize: compact ? 16 : 20,
                onPressed: onEdit,
              );
              final heading = Row(
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: AppText(
                      title,
                      role: AppTextRole.subtitle,
                      maxLines: 1,
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
          if (isEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            AppText(emptyHint, role: AppTextRole.caption),
          ] else ...[
            const SizedBox(height: AppTheme.spaceGroup),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.spaceXs),
              _DetailEntryTile(
                child: _DetailEntryRow(
                  key: ValueKey(
                    '${visible[i].title}\u0000${visible[i].body}',
                  ),
                  entry: visible[i],
                  previewLines: previewLines,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Inset tile inside a section card (NT lorebook-entry nesting).
class _DetailEntryTile extends StatelessWidget {
  const _DetailEntryTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = scheme.surfaceContainerHighest;
    final depth = theme.brightness == Brightness.dark ? 0.1 : 0.05;
    final fill = Color.alphaBlend(
      Colors.black.withValues(alpha: depth),
      base,
    );
    final shape = AppUiTokens.of(context).shape(
      side: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.32),
      ),
    );

    return Material(
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceMd,
        ),
        child: child,
      ),
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
  bool _canExpand = false;

  @override
  void didUpdateWidget(covariant _DetailEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.title != widget.entry.title ||
        oldWidget.entry.body != widget.entry.body ||
        !_sameTags(oldWidget.entry.tags, widget.entry.tags)) {
      _expanded = false;
      _canExpand = false;
    }
  }

  bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onOverflow(bool exceeds) {
    if (_canExpand == exceeds) return;
    setState(() => _canExpand = exceeds);
  }

  Future<void> _copy() async {
    final text = widget.entry.clipboardText;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制：${widget.entry.copyLabel}')),
    );
  }

  static const double _entryActionSize = 28;
  static const double _entryActionIcon = 16;

  List<Widget> _entryActions({required bool hasCopy, required bool hasBody}) {
    return <Widget>[
      if (hasCopy)
        AppIconButton(
          icon: Icons.copy_outlined,
          tooltip: '复制',
          size: _entryActionSize,
          iconSize: _entryActionIcon,
          onPressed: _copy,
        ),
      if (hasBody && _canExpand)
        AppIconButton(
          icon: _expanded ? Icons.expand_less : Icons.expand_more,
          tooltip: _expanded ? '收起' : '展开',
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
    final hasCopy = widget.entry.clipboardText.isNotEmpty;
    final actions = _entryActions(hasCopy: hasCopy, hasBody: body.isNotEmpty);

    return Column(
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
            text: body,
            expanded: _expanded,
            previewLines: widget.previewLines,
            role: AppTextRole.compactBody,
            onOverflowChanged: _onOverflow,
          ),
        ],
      ],
    );
  }
}

class _EntryTagWrap extends StatelessWidget {
  const _EntryTagWrap({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = AppUiTokens.of(context).shape();

    return Wrap(
      spacing: AppTheme.spaceXs,
      runSpacing: AppTheme.spaceXs,
      children: [
        for (final tag in tags)
          if (tag.trim().isNotEmpty)
            DecoratedBox(
              decoration: ShapeDecoration(
                color: Color.alphaBlend(
                  Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.14
                        : 0.07,
                  ),
                  scheme.surfaceContainerHighest,
                ),
                shape: shape,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: AppTheme.spaceXs,
                ),
                child: AppText(tag.trim(), role: AppTextRole.caption),
              ),
            ),
      ],
    );
  }
}