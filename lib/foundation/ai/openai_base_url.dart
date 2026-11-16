/// Normalizes an OpenAI-compatible API root (no trailing slash, no endpoint path).
String normalizeOpenAiBaseUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  const suffixes = <String>['/chat/completions', '/models'];
  for (final suffix in suffixes) {
    if (url.toLowerCase().endsWith(suffix)) {
      url = url.substring(0, url.length - suffix.length);
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      break;
    }
  }
  return url;
}
