/// Import profile: store Markdown, strip all HTML (convert mappable tags to MD).
class ImportTextProfile {
  const ImportTextProfile();
}

/// Deterministic HTML removal / HTML→Markdown for character-card and import text.
class RichTextSanitizer {
  const RichTextSanitizer({this.profile = const ImportTextProfile()});

  final ImportTextProfile profile;

  static final RegExp _tagPattern = RegExp(
    r'<\s*/?\s*([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>',
    caseSensitive: false,
  );

  /// Returns true if [text] still contains an HTML-like tag.
  static bool containsHtmlTag(String text) {
    return _tagPattern.hasMatch(text);
  }

  String sanitize(String input) {
    if (input.isEmpty) return input;
    var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = _decodeEntities(text);
    if (!containsHtmlTag(text)) {
      return _normalizeMarkdown(text);
    }
    text = _stripScriptAndStyle(text);
    text = _convertPreCodeBlocks(text);
    text = _convertBlockBreaks(text);
    text = _convertHeaders(text);
    text = _convertLists(text);
    text = _convertInlineSemantic(text);
    text = _stripRemainingTags(text);
    text = _normalizeMarkdown(text);
    return text;
  }

  String normalizeForFingerprint(String text) {
    return sanitize(text)
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .trim();
  }

  String _stripScriptAndStyle(String text) {
    return text
        .replaceAll(
          RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  }

  String _decodeEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1)!);
          if (code == null) return m.group(0)!;
          return String.fromCharCode(code);
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1)!, radix: 16);
          if (code == null) return m.group(0)!;
          return String.fromCharCode(code);
        });
  }

  String _convertPreCodeBlocks(String text) {
    return text.replaceAllMapped(
      RegExp(
        r'<pre\b[^>]*>([\s\S]*?)</pre>',
        caseSensitive: false,
      ),
      (m) {
        var inner = m.group(1) ?? '';
        inner = inner.replaceAll(
          RegExp(r'<\s*/?\s*code\b[^>]*>', caseSensitive: false),
          '',
        );
        inner = _stripRemainingTags(inner);
        return '\n```\n${inner.trim()}\n```\n';
      },
    );
  }

  String _convertBlockBreaks(String text) {
    return text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*(p|div|tr)\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<\s*(p|div)\b[^>]*>', caseSensitive: false), '');
  }

  String _convertHeaders(String text) {
    for (var level = 6; level >= 1; level--) {
      final hashes = '#' * level;
      text = text.replaceAllMapped(
        RegExp(
          r'<\s*h$level\b[^>]*>([\s\S]*?)</\s*h$level\s*>',
          caseSensitive: false,
        ),
        (m) => '\n$hashes ${_stripRemainingTags(m.group(1) ?? '').trim()}\n',
      );
    }
    return text;
  }

  String _convertLists(String text) {
    text = text.replaceAllMapped(
      RegExp(r'<\s*li\b[^>]*>([\s\S]*?)</\s*li\s*>', caseSensitive: false),
      (m) {
        final inner = _stripRemainingTags(m.group(1) ?? '').trim();
        return '\n- $inner';
      },
    );
    return text.replaceAll(
      RegExp(r'<\s*/?\s*(ul|ol)\b[^>]*>', caseSensitive: false),
      '\n',
    );
  }

  String _convertInlineSemantic(String text) {
    const pairs = <String, String>{
      'strong': '**',
      'b': '**',
      'em': '*',
      'i': '*',
    };
    for (final entry in pairs.entries) {
      final tag = entry.key;
      final mark = entry.value;
      text = text.replaceAllMapped(
        RegExp(
          '<\\s*$tag\\b[^>]*>([\\s\\S]*?)</\\s*$tag\\s*>',
          caseSensitive: false,
        ),
        (m) => '$mark${_stripRemainingTags(m.group(1) ?? '').trim()}$mark',
      );
    }
    text = text.replaceAllMapped(
      RegExp(r'<\s*code\b[^>]*>([\s\S]*?)</\s*code\s*>', caseSensitive: false),
      (m) => '`${_stripRemainingTags(m.group(1) ?? '').trim()}`',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'<\s*blockquote\b[^>]*>([\s\S]*?)</\s*blockquote\s*>',
        caseSensitive: false,
      ),
      (m) {
        final inner = _stripRemainingTags(m.group(1) ?? '').trim();
        final lines = inner.split('\n').map((l) => '> ${l.trim()}').join('\n');
        return '\n$lines\n';
      },
    );
    text = text.replaceAllMapped(
      RegExp(
        r'''<\s*a\b[^>]*href\s*=\s*["']([^"']*)["'][^>]*>([\s\S]*?)</\s*a\s*>''',
        caseSensitive: false,
      ),
      (m) {
        final label = _stripRemainingTags(m.group(2) ?? '').trim();
        final href = (m.group(1) ?? '').trim();
        if (label.isEmpty) return '';
        if (href.isEmpty) return label;
        return '[$label]($href)';
      },
    );
    return text;
  }

  String _stripRemainingTags(String text) {
    var out = text.replaceAll(_tagPattern, '');
    while (containsHtmlTag(out)) {
      final next = out.replaceAll(_tagPattern, '');
      if (next == out) break;
      out = next;
    }
    return out;
  }

  String _normalizeMarkdown(String text) {
    var out = text.replaceAll('__', '**');
    out = out.split('\n').map((l) => l.trimRight()).join('\n');
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return out.trim();
  }
}