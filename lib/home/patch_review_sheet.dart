import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/main/patch_preview.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Lets the user tick which patch ops to write back, with field-level diffs.
///
/// Returns the ticked op indexes, or null when the user skips the proposal.
Future<Set<int>?> showPatchReviewSheet({
  required BuildContext context,
  required List<PatchPreviewItem> items,
  required Set<int> initialSelection,
}) {
  return showAppSheet<Set<int>>(
    context: context,
    size: AppSheetSize.half,
    builder: (sheetContext) =>
        _PatchReviewBody(items: items, initialSelection: initialSelection),
  );
}

class _PatchReviewBody extends StatefulWidget {
  const _PatchReviewBody({required this.items, required this.initialSelection});

  final List<PatchPreviewItem> items;
  final Set<int> initialSelection;

  @override
  State<_PatchReviewBody> createState() => _PatchReviewBodyState();
}

class _PatchReviewBodyState extends State<_PatchReviewBody> {
  late final Set<int> _selected = {...widget.initialSelection};

  void _toggle(int index, bool on) {
    setState(() {
      if (on) {
        _selected.add(index);
      } else {
        _selected.remove(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final items = widget.items;
    return AppSheetScrollBody(
      footer: [
        AppButton(
          label: strings.applySelectedCount(_selected.length),
          expanded: true,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<int>.of(_selected)),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        AppButton(
          label: strings.skipWrite,
          variant: AppButtonVariant.ghost,
          expanded: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      children: [
        AppText(strings.patchReviewTitle, role: AppTextRole.subtitle),
        const SizedBox(height: AppTheme.spaceMd),
        for (var i = 0; i < items.length; i++) ...[
          _PatchOpRow(
            item: items[i],
            selected: _selected.contains(items[i].index),
            onChanged:
                items[i].usable ? (on) => _toggle(items[i].index, on) : null,
          ),
          if (i < items.length - 1) const AppListHairline(),
        ],
      ],
    );
  }
}

class _PatchOpRow extends StatelessWidget {
  const _PatchOpRow({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final PatchPreviewItem item;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final changes = item.changes;
    final first = changes.isEmpty ? null : changes.first;
    final headline = first == null ? null : _entityLine(context, first);
    final extra = changes.length > 1 ? changes.length - 1 : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.spaceXs),
          child: AppSwitch(value: selected, onChanged: onChanged),
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  _title(context, headline, extra),
                  role: AppTextRole.subtitle,
                ),
                if (item.error != null) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  AppText(
                    item.error!,
                    role: AppTextRole.caption,
                    color: scheme.error,
                  ),
                ] else if (first == null) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  AppText(strings.patchNoChange, role: AppTextRole.caption),
                ] else ...[
                  ..._changeDetail(context, first),
                  for (final change in changes.skip(1))
                    ..._changeDetail(context, change, showHeadline: true),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _title(BuildContext context, String? headline, int extra) {
    final strings = context.strings;
    if (headline == null) return strings.patchOpFailed;
    if (extra <= 0) return headline;
    return '$headline 等 ${extra + 1} 处';
  }

  List<Widget> _changeDetail(
    BuildContext context,
    PatchEntityChange change, {
    bool showHeadline = false,
  }) {
    final strings = context.strings;
    return [
      if (showHeadline) ...[
        const SizedBox(height: AppTheme.spaceSm),
        AppText(_entityLine(context, change), role: AppTextRole.caption),
      ],
      for (final field in change.fields) ...[
        const SizedBox(height: AppTheme.spaceXs),
        AppText(
          strings.patchFieldLabel(field.field),
          role: AppTextRole.caption,
          fontWeight: FontWeight.w600,
        ),
        if (field.isEdited)
          AppText(
            '${strings.patchBeforeLabel}：${_valueText(context, field.before)}',
            role: AppTextRole.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        if (!field.isRemoved)
          AppText(
            '${strings.patchAfterLabel}：${_valueText(context, field.after)}',
            role: AppTextRole.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    ];
  }

  String _entityLine(BuildContext context, PatchEntityChange change) {
    final strings = context.strings;
    final verb = change.added
        ? strings.patchOpAdded
        : (change.removed ? strings.patchOpRemoved : strings.patchOpEdited);
    final kind = switch (change.kind) {
        PatchTargetKind.worldBook => strings.patchKindWorldBook,
        PatchTargetKind.cast => strings.patchKindCast,
        PatchTargetKind.node => strings.patchKindNode,
        PatchTargetKind.edge => strings.patchKindEdge,
        PatchTargetKind.storySummary => strings.patchKindStorySummary,
        PatchTargetKind.plotElement => strings.patchKindPlotElement,
      };
    final label = change.label.trim();
    return label.isEmpty ? '$verb$kind' : '$verb$kind：$label';
  }

  String _valueText(BuildContext context, Object? value) {
    final strings = context.strings;
    if (value == null) return strings.patchEmptyValue;
    if (value is bool) {
      return value ? strings.patchTrueValue : strings.patchFalseValue;
    }
    if (value is List) {
      if (value.isEmpty) return strings.patchEmptyValue;
      return value.join('、');
    }
    final text = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? strings.patchEmptyValue : text;
  }
}
