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
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: AppText(title, role: AppTextRole.subtitle),
              ),
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: '编辑',
                size: 36,
                iconSize: 20,
                onPressed: onEdit,
              ),
            ],
          ),
          if (isEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            AppText(emptyHint, role: AppTextRole.caption),
          ] else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i == 0)
                    const SizedBox(height: AppTheme.spaceSm)
                  else ...[
                    const SizedBox(height: AppTheme.spaceMd),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                  ],
                  _DetailEntryRow(
                    key: ValueKey(
                      '${visible[i].title}\u0000${visible[i].body}',
                    ),
                    entry: visible[i],
                    previewLines: previewLines,
                  ),
                ],
              ],
            ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final title = widget.entry.title.trim();
    final body = widget.entry.body.trim();
    final hasCopy = widget.entry.clipboardText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title.isNotEmpty)
                    AppText(title, role: AppTextRole.label),
                  if (widget.entry.tags.isNotEmpty) ...[
                    if (title.isNotEmpty)
                      const SizedBox(height: AppTheme.spaceXs),
                    _EntryTagWrap(tags: widget.entry.tags),
                  ],
                ],
              ),
            ),
            if (hasCopy)
              AppIconButton(
                icon: Icons.copy_outlined,
                tooltip: '复制',
                size: 32,
                iconSize: 18,
                onPressed: _copy,
              ),
            if (body.isNotEmpty && _canExpand)
              AppIconButton(
                icon: _expanded ? Icons.expand_less : Icons.expand_more,
                tooltip: _expanded ? '收起' : '展开',
                size: 32,
                iconSize: 18,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
          ],
        ),
        if (body.isNotEmpty) ...[
          if (title.isNotEmpty || widget.entry.tags.isNotEmpty)
            const SizedBox(height: AppTheme.spaceXs),
          AppExpandableText(
            text: body,
            expanded: _expanded,
            previewLines: widget.previewLines,
            role: AppTextRole.body,
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
                color: scheme.surfaceContainerHighest,
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