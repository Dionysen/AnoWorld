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
  bool _measureScheduled = false;

  @override
  void didUpdateWidget(covariant AppExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.role != widget.role ||
        oldWidget.previewLines != widget.previewLines) {
      _exceedsPreview = null;
      _measureScheduled = false;
    }
  }

  void _measureIfNeeded(double maxWidth, TextStyle style) {
    if (_exceedsPreview != null ||
        _measureScheduled ||
        maxWidth <= 0 ||
        widget.text.isEmpty) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted || _exceedsPreview != null) return;

      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.previewLines,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: maxWidth);
      final exceeds = painter.didExceedMaxLines;
      _exceedsPreview = exceeds;
      widget.onOverflowChanged?.call(exceeds);
    });
  }

  TextStyle? _textStyle(TextTheme theme) {
    return switch (widget.role) {
      AppTextRole.pageTitle => theme.headlineSmall,
      AppTextRole.title => theme.titleLarge,
      AppTextRole.subtitle => theme.titleMedium,
      AppTextRole.body => theme.bodyLarge,
      AppTextRole.caption => theme.bodySmall,
      AppTextRole.label => theme.labelLarge,
      AppTextRole.compactBody => theme.bodySmall?.copyWith(height: 1.35),
      AppTextRole.compactLabel => theme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
      AppTextRole.compactTag => theme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _textStyle(Theme.of(context).textTheme);
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