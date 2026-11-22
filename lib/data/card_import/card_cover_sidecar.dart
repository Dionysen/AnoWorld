import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/foundation/io/png_text_chunks.dart';
import 'package:path/path.dart' as p;

/// Reads the PNG sitting beside a JSON card (same base name).
///
/// Some card exports ship `name.json` plus `name.png`; the PNG is the card
/// face and doubles as the story cover. Returns null when absent or not a PNG.
Future<Uint8List?> readCardCoverSidecar(String jsonPath) async {
  final candidate = File(p.setExtension(jsonPath, '.png'));
  if (!await candidate.exists()) return null;
  final bytes = await candidate.readAsBytes();
  if (!isPngBytes(bytes)) return null;
  return bytes;
}
