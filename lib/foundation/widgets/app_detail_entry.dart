/// One lorebook-style row on the story detail page: title, tags, body.
class AppDetailEntry {
  const AppDetailEntry({
    required this.title,
    required this.body,
    this.tags = const <String>[],
  });

  final String title;
  final String body;
  final List<String> tags;

  /// Plain text for clipboard (title, tags, then body).
  ///
  /// [separator] joins the tags, so the caller passes its language's list
  /// separator.
  String clipboardText(String separator) {
    final lines = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) lines.add(trimmedTitle);
    final tagLine = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (tagLine.isNotEmpty) lines.add(tagLine.join(separator));
    final trimmedBody = body.trim();
    if (trimmedBody.isNotEmpty) lines.add(trimmedBody);
    return lines.join('\n');
  }

  /// Short name for the copy toast; [fallback] names a row with no text.
  String copyLabel(String fallback) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) return trimmedTitle;
    final tagLine = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (tagLine.isNotEmpty) return tagLine.first;
    return fallback;
  }

  /// Whether there is anything to copy. (Empty rows carry no action.)
  bool get hasClipboardText =>
      title.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      tags.any((t) => t.trim().isNotEmpty);
}
