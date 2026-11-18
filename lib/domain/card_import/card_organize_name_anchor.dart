/// Whether a proposed cast name actually appears as a person marker in source text.
abstract final class CardOrganizeNameAnchor {
  static bool isAnchoredInSource(String name, String body) {
    final n = name.trim();
    if (n.isEmpty || body.isEmpty) return false;
    final e = RegExp.escape(n);
    final anchors = <RegExp>[
      RegExp(r'(?:^|\n)\s*' + e + r'\s*[:：]\s*\S'),
      RegExp(r'【\s*' + e + r'\s*】'),
      RegExp(r'(?:^|\n)\s*#{1,3}\s*' + e + r'\s*(?:\n|$)'),
      RegExp(r'\*\*\s*' + e + r'\s*\*\*'),
    ];
    return anchors.any((pattern) => pattern.hasMatch(body));
  }
}