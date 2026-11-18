import 'package:anoworld/domain/card_import/card_organize_character_names.dart';
import 'package:anoworld/domain/card_import/card_organize_name_anchor.dart';

/// Format-agnostic: any `专名: 叙述` line that looks like a character blurb.
abstract final class CardOrganizeCastLineScanner {
  static final RegExp _kvLine = RegExp(
    r'^\s*([^\s:：\n]{1,24})[:：]\s+(.+?)\s*$',
  );

  static List<({String name, String line})> scan(String body) {
    final out = <({String name, String line})>[];
    final seen = <String>{};
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      final m = _kvLine.firstMatch(line);
      if (m == null) continue;
      final name = m.group(1)?.trim() ?? '';
      final desc = m.group(2)?.trim() ?? '';
      if (name.isEmpty || desc.isEmpty) continue;
      if (seen.contains(name)) continue;
      if (!CardOrganizeNameAnchor.isAnchoredInSource(name, body)) continue;
      if (CardOrganizeCharacterNames.isFieldLabel(name)) continue;
      if (!CardOrganizeCharacterNames.isPlausibleNewCharacterName(
        name,
        bodyChars: desc.length,
      )) {
        continue;
      }
      if (!_looksLikeCharacterBlurb(desc)) continue;
      if (!body.contains(line)) continue;
      seen.add(name);
      out.add((name: name, line: line));
    }
    return out;
  }

  static bool _looksLikeCharacterBlurb(String text) {
    final t = text.trim();
    if (t.length < 4) return false;
    if (RegExp(r'^[\d+\-./]+$').hasMatch(t)) return false;
    if (t.contains('，') || t.contains(',') || t.contains('、')) return true;
    if (t.length >= 6) return true;
    return false;
  }
}