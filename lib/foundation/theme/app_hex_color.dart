import 'package:flutter/painting.dart';

/// Parses `#RRGGBB` or `#AARRGGBB` (leading `#` optional).
///
/// Returns `null` when [raw] is not a readable hex color.
Color? tryParseHexColor(String? raw) {
  if (raw == null) return null;
  var value = raw.trim().replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Opaque `#RRGGBB` used for persisted colors and compact readouts.
String hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
