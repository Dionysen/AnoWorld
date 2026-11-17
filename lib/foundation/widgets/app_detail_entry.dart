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
  String get clipboardText {
    final lines = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) lines.add(trimmedTitle);
    final tagLine = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (tagLine.isNotEmpty) lines.add(tagLine.join('、'));
    final trimmedBody = body.trim();
    if (trimmedBody.isNotEmpty) lines.add(trimmedBody);
    return lines.join('\n');
  }

  String get copyLabel {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) return trimmedTitle;
    final tagLine = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (tagLine.isNotEmpty) return tagLine.first;
    return '条目';
  }
}