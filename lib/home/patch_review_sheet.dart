import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/main/patch_preview.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// One tickable line inside the review sheet.
///
/// Ops-backed rows carry a [PatchPreviewItem] so the sheet can render the
/// field diffs; rows without one (a whole-graph rewrite, for example) only
/// show [title] plus an optional [note].
class PatchReviewRow {
  const PatchReviewRow({
    required this.id,
    this.item,
    this.title,
    this.note,
    this.details = const <String>[],
    this.selected = true,
    this.enabled = true,
  });

  /// Stable key returned when the user confirms; unique across groups.
  final String id;
  final PatchPreviewItem? item;
  final String? title;
  final String? note;

  /// Read-only lines under [note] (whole-graph stations, for example).
  final List<String> details;
  final bool selected;
  final bool enabled;
}

/// One layer's worth of rows, shown under a header when several are present.
class PatchReviewGroup {
  const PatchReviewGroup({required this.title, required this.rows});

  final String title;
  final List<PatchReviewRow> rows;
}

/// Lets the user tick which changes to write back, with field-level diffs.
///
/// Layers are grouped (world / cast / graph / plot) and confirmed together, so
/// a cross-layer turn writes every layer from one sheet and one save.
///
/// Returns the ticked row ids, or null when the user skips the proposal.
Future<Set<String>?> showPatchReviewSheet({
  required BuildContext context,
  required List<PatchReviewGroup> groups,
  Set<String> initialSelection = const <String>{},
}) {
  return showAppSheet<Set<String>>(
    context: context,
    size: AppSheetSize.half,
    builder: (sheetContext) =>
        _PatchReviewBody(groups: groups, initialSelection: initialSelection),
  );
}

class _PatchReviewBody extends StatefulWidget {
  const _PatchReviewBody({
    required this.groups,
    required this.initialSelection,
  });

  final List<PatchReviewGroup> groups;
  final Set<String> initialSelection;

  @override
  State<_PatchReviewBody> createState() => _PatchReviewBodyState();
}

class _PatchReviewBodyState extends State<_PatchReviewBody> {
  late final Set<String> _selected = {
    for (final group in widget.groups)
      for (final row in group.rows)
        if (widget.initialSelection.contains(row.id)) row.id,
  };

  void _toggle(String id, bool on) {
    setState(() {
      if (on) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final groups = [
      for (final group in widget.groups)
        if (group.rows.isNotEmpty) group,
    ];
    final showHeaders = groups.length > 1;
    return AppSheetScrollBody(
      footer: [
        AppButton(
          label: strings.applySelectedCount(_selected.length),
          expanded: true,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.of(_selected)),
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
        for (var g = 0; g < groups.length; g++) ...[
          if (showHeaders) ...[
            const SizedBox(height: AppTheme.spaceMd),
            AppText(
              groups[g].title,
              role: AppTextRole.caption,
              fontWeight: FontWeight.w600,
            ),
          ] else
            const SizedBox(height: AppTheme.spaceMd),
          for (var i = 0; i < groups[g].rows.length; i++) ...[
            _ReviewRow(
              row: groups[g].rows[i],
              selected: _selected.contains(groups[g].rows[i].id),
              onChanged: groups[g].rows[i].enabled
                  ? (on) => _toggle(groups[g].rows[i].id, on)
                  : null,
            ),
            if (i < groups[g].rows.length - 1) const AppListHairline(),
          ],
        ],
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.row,
    required this.selected,
    required this.onChanged,
  });

  final PatchReviewRow row;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final item = row.item;
    final changes = item?.changes ?? const <PatchEntityChange>[];
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
                  item == null
                      ? (row.title ?? '')
                      : _title(context, headline, extra),
                  role: AppTextRole.subtitle,
                ),
                if (row.note != null) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  AppText(row.note!, role: AppTextRole.caption),
                ],
                for (final detail in row.details) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  AppText(detail, role: AppTextRole.caption),
                ],
                if (item?.error != null) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  AppText(
                    item!.error!,
                    role: AppTextRole.caption,
                    color: scheme.error,
                  ),
                ] else if (item != null && first == null) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  AppText(strings.patchNoChange, role: AppTextRole.caption),
                ] else if (item != null && first != null) ...[
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
