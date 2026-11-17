import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_expandable_text.dart';
import 'app_icon_button.dart';
import 'app_surface.dart';
import 'app_text.dart';

/// Structured story-detail block: title, short preview, expand, edit entry.
class AppDetailSectionCard extends StatefulWidget {
  const AppDetailSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    required this.onEdit,
    this.emptyHint,
    this.previewLines = 3,
  });

  final String title;
  final IconData icon;
  final String body;
  final VoidCallback onEdit;
  final String? emptyHint;
  final int previewLines;

  @override
  State<AppDetailSectionCard> createState() => _AppDetailSectionCardState();
}

class _AppDetailSectionCardState extends State<AppDetailSectionCard> {
  bool _expanded = false;
  bool _canExpand = false;

  @override
  void didUpdateWidget(covariant AppDetailSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      _expanded = false;
      _canExpand = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = widget.body.trim();
    final isEmpty = trimmed.isEmpty;
    final emptyHint = widget.emptyHint ?? '这里还没有内容';

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: AppText(widget.title, role: AppTextRole.subtitle),
              ),
              if (!isEmpty && _canExpand)
                AppIconButton(
                  icon: _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  tooltip: _expanded ? '收起' : '展开',
                  size: 36,
                  iconSize: 20,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: '编辑',
                size: 36,
                iconSize: 20,
                onPressed: widget.onEdit,
              ),
            ],
          ),
          if (isEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            AppText(emptyHint, role: AppTextRole.caption),
          ] else ...[
            const SizedBox(height: AppTheme.spaceSm),
            AppExpandableText(
              text: trimmed,
              expanded: _expanded,
              previewLines: widget.previewLines,
              role: AppTextRole.body,
              onOverflowChanged: (exceeds) {
                if (_canExpand == exceeds) return;
                setState(() => _canExpand = exceeds);
              },
            ),
            if (_canExpand && !_expanded)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spaceXs),
                  child: AppButton(
                    label: '展开',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => setState(() => _expanded = true),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}