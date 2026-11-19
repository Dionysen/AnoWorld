import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:flutter/material.dart';

/// Row subtitle for a pack: element count plus a short keyword preview.
String describePlotElementPack(
  PlotElementCatalog catalog,
  PlotElementPack pack,
) {
  final elements = catalog.elementsOfPack(pack);
  if (elements.isEmpty) return '还空着';
  final preview = elements.take(3).map((e) => e.keyword).join('、');
  final ellipsis = elements.length > 3 ? '…' : '';
  return '${elements.length} 条 · $preview$ellipsis';
}

/// Explains what switching a pack on changes; shown only when it overlaps.
String describePackApplyImpact(PackApplyPlan plan) {
  final names = plan.overlapNames.map((name) => '「$name」').join('');
  return <String>[
    if (plan.addedIds.isNotEmpty) '新增 ${plan.addedIds.length} 条',
    if (plan.manualSharedIds.isNotEmpty)
      '其中 ${plan.manualSharedIds.length} 条你单独勾过，会算作这个包的一部分；取消这个包时也会一起取消',
    if (plan.overlappedIds.isNotEmpty)
      '其中 ${plan.overlappedIds.length} 条已被$names用到，取消这个包时会保留',
  ].join('；');
}

/// Explains what switching a pack off changes; shown only when ids stay kept.
String describePackRemoveImpact(PackRemovePlan plan) {
  final names = plan.keptByNames.map((name) => '「$name」').join('');
  final kept = '${plan.keptIds.length} 条仍被$names用到，会保留';
  if (plan.removedIds.isEmpty) return kept;
  return '$kept；其余 ${plan.removedIds.length} 条会取消勾选';
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
    hint: '雨夜悬疑、校园日常…',
  );
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
