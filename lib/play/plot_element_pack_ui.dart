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
