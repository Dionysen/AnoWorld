import 'package:flutter/material.dart';

import 'app_text.dart';

/// Collapsed preview for multi-line body copy; expansion state lives in the parent.
class AppExpandableText extends StatefulWidget {
  const AppExpandableText({
    super.key,
    required this.text,
    required this.expanded,
    this.previewLines = 3,
    this.role = AppTextRole.body,
    this.onOverflowChanged,
  });

  final String text;
  final bool expanded;
  final int previewLines;
  final AppTextRole role;
  final ValueChanged<bool>? onOverflowChanged;

  @override
  State<AppExpandableText> createState() => _AppExpandableTextState();
}

class _AppExpandableTextState extends State<AppExpandableText> {
  bool? _exceedsPreview;

  @override
  void didUpdateWidget(covariant AppExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.role != widget.role) {
      _exceedsPreview = null;
    }
  }

  void _measureIfNeeded(double maxWidth, TextStyle style) {
    if (_exceedsPreview != null || maxWidth <= 0 || widget.text.isEmpty) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.previewLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    final exceeds = painter.didExceedMaxLines;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _exceedsPreview == exceeds) return;
      setState(() => _exceedsPreview = exceeds);
      widget.onOverflowChanged?.call(exceeds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (style != null) {
          _measureIfNeeded(constraints.maxWidth, style);
        }
        return AppText(
          widget.text,
          role: widget.role,
          maxLines: widget.expanded ? null : widget.previewLines,
          overflow:
              widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        );
      },
    );
  }
}