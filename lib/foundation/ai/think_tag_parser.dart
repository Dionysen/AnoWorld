/// Splits a leading `<think>` / `<thinking>` / … block from model text.
///
/// Aligned with NativeTavern `ThinkTagParser.extract` (non-streaming).
abstract final class ThinkTagParser {
  static final RegExp _leading = RegExp(
    r'^\s*<(thinking|think|thought|reasoning)>([\s\S]*?)</\1>\s*',
    caseSensitive: false,
  );

  /// Returns `(content, reasoning)`; [reasoning] is null when no leading block.
  static (String, String?) extract(String text) {
    final match = _leading.firstMatch(text);
    if (match == null) return (text, null);
    final reasoning = match.group(2)?.trim();
    if (reasoning == null || reasoning.isEmpty) {
      return (text.substring(match.end), null);
    }
    return (text.substring(match.end), reasoning);
  }
}
