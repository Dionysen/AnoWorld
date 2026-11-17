import 'package:flutter/material.dart';

import '../theme/app_chat_chrome.dart';

/// Matches spoken dialogue wrapped in common quotation marks (NT).
final RegExp appDialogueQuotePattern = RegExp(
  r'"([^"\n]{1,800})"'
  r'|“([^”\n]{1,800})”'
  r'|「([^」\n]{1,800})」',
);

/// Renders bubble body with quoted dialogue tinted/bold (NT dialogue style).
class AppChatDialogueText extends StatelessWidget {
  const AppChatDialogueText({
    super.key,
    required this.text,
    this.isUser = false,
    this.lineHeight = AppChatChrome.defaultLineHeight,
    this.paragraphSpacing = AppChatChrome.defaultParagraphSpacing,
  });

  final String text;
  final bool isUser;
  final double lineHeight;
  final double paragraphSpacing;

  @override
  Widget build(BuildContext context) {
    final base = AppChatChrome.bubbleBodyStyle(
      context,
      lineHeight: lineHeight,
    );
    final dialogue = base.copyWith(
      color: AppChatChrome.dialogueTextColor(context),
      fontWeight: AppChatChrome.dialogueFontWeight,
    );
    final paragraphs = _paragraphs(text);
    if (paragraphs.length <= 1) {
      return Text.rich(
        TextSpan(children: _spans(paragraphs.firstOrNull ?? '', base, dialogue)),
        textAlign: TextAlign.start,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) SizedBox(height: paragraphSpacing),
          Text.rich(
            TextSpan(children: _spans(paragraphs[i], base, dialogue)),
            textAlign: TextAlign.start,
          ),
        ],
      ],
    );
  }

  /// Blank-line separated paragraphs; single newlines stay inside a block.
  static List<String> _paragraphs(String source) {
    final trimmed = source.replaceAll('\r\n', '\n');
    if (trimmed.trim().isEmpty) return const [''];
    return trimmed
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  static List<InlineSpan> _spans(
    String source,
    TextStyle base,
    TextStyle dialogue,
  ) {
    if (source.isEmpty) {
      return [TextSpan(text: '', style: base)];
    }
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in appDialogueQuotePattern.allMatches(source)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: source.substring(start, match.start), style: base),
        );
      }
      spans.add(TextSpan(text: match.group(0)!, style: dialogue));
      start = match.end;
    }
    if (start < source.length) {
      spans.add(TextSpan(text: source.substring(start), style: base));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: source, style: base));
    }
    return spans;
  }
}
