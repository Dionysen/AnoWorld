import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:flutter/material.dart';

/// Row subtitle for a pack: element count plus a short keyword preview.
String describePlotElementPack(
  BuildContext context,
  PlotElementCatalog catalog,
  PlotElementPack pack,
) {
  final strings = context.strings;
  final elements = catalog.elementsOfPack(pack);
  if (elements.isEmpty) return strings.countLabel(0);
  final preview = elements
      .take(3)
      .map((element) => element.keyword)
      .join(strings.listSeparator);
  final ellipsis = elements.length > 3 ? '…' : '';
  return strings.packSummary(elements.length, '$preview$ellipsis');
}

/// Explains what switching a pack on changes; shown only when it overlaps.
String describePackApplyImpact(BuildContext context, PackApplyPlan plan) {
  return context.strings.packApplyImpact(
    PackApplyPlanText(
      addedCount: plan.addedIds.length,
      manualSharedCount: plan.manualSharedIds.length,
      overlappedCount: plan.overlappedIds.length,
      overlapNames: plan.overlapNames,
    ),
  );
}

/// Explains what switching a pack off changes; shown only when ids stay kept.
String describePackRemoveImpact(BuildContext context, PackRemovePlan plan) {
  return context.strings.packRemoveImpact(
    PackRemovePlanText(
      removedCount: plan.removedIds.length,
      keptCount: plan.keptIds.length,
      keptByNames: plan.keptByNames,
    ),
  );
}

/// Asks for a plot-element pack name; null when dismissed or left blank.
Future<String?> askPlotElementPackName(
  BuildContext context, {
  required String title,
  String initialName = '',
}) async {
  final name = await showAppTextEditSheet(
    context: context,
    title: title,
    initialValue: initialName,
    hint: context.strings.packNameHint,
  );
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
