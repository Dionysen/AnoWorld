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
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final base = AppChatChrome.bubbleBodyStyle(context);
    final dialogue = base.copyWith(
      color: AppChatChrome.dialogueTextColor(context),
      fontWeight: AppChatChrome.dialogueFontWeight,
    );
    return Text.rich(
      TextSpan(children: _spans(text, base, dialogue)),
      textAlign: isUser ? TextAlign.start : TextAlign.start,
    );
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
