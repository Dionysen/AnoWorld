/// SillyTavern still expands these legacy angle-bracket placeholders when a
/// prompt is built, so cards written for it keep them in the raw text. Our
/// HTML sweep would delete them as tags and leave broken sentences, so they
/// are rewritten to the macro form first.
///
/// Order matters: `<CHARIFNOTGROUP>` must be matched before `<CHAR>`.
const Map<String, String> _legacyPlaceholders = <String, String>{
  '<CHARIFNOTGROUP>': '{{char}}',
  '<CHAR>': '{{char}}',
  '<BOT>': '{{char}}',
  '<USER>': '{{user}}',
  '<GROUP>': '{{group}}',
};

/// Rewrites SillyTavern legacy placeholders to their `{{macro}}` form.
String normalizeLegacyCardPlaceholders(String text) {
  if (!text.contains('<')) return text;
  var out = text;
  for (final entry in _legacyPlaceholders.entries) {
    out = out.replaceAll(
      RegExp(RegExp.escape(entry.key), caseSensitive: false),
      entry.value,
    );
  }
  return out;
}
