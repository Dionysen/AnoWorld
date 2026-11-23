import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:flutter/widgets.dart';

/// Relative label for a save timestamp, so the list row and the detail pane
/// always read the same.
String saveTimeLabel(BuildContext context, DateTime at) {
  final strings = context.strings;
  final local = at.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return strings.justNow;
  if (diff.inHours < 1) return strings.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return strings.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return strings.daysAgo(diff.inDays);
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
