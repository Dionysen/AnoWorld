import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:flutter/material.dart';

/// Asks for a plot-element category name; null when dismissed or left blank.
Future<String?> askPlotElementCategoryName(
  BuildContext context, {
  required String title,
  String initialName = '',
}) async {
  final name = await showAppTextEditSheet(
    context: context,
    title: title,
    initialValue: initialName,
    hint: '日常、情感、危机…',
  );
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
