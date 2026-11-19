import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_disclosure_icon.dart';
import 'app_text.dart';

/// Collapsible chain-of-thought block inside a chat bubble (NT-aligned).
class AppChatReasoning extends StatefulWidget {
  const AppChatReasoning({
    super.key,
    required this.reasoning,
    this.label,
    this.initiallyExpanded = false,
  });

  final String reasoning;

  /// Header label; defaults to the shared "thinking" copy.
  final String? label;
  final bool initiallyExpanded;

  @override
  State<AppChatReasoning> createState() => _AppChatReasoningState();
}

class _AppChatReasoningState extends State<AppChatReasoning> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant AppChatReasoning oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reasoning != widget.reasoning &&
        widget.initiallyExpanded &&
        !_expanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.reasoning.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final tokens = AppUiTokens.of(context);
    final fill = scheme.onSurface.withValues(
      alpha: scheme.brightness == Brightness.dark ? 0.08 : 0.05,
    );
    final border = scheme.primary.withValues(alpha: 0.28);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(tokens.radius),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(tokens.radius),
                  bottom: Radius.circular(_expanded ? 0 : tokens.radius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs + 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: AppTheme.spaceXs),
                      Expanded(
                        child: AppText(
                          widget.label ?? context.ui.thinking,
                          role: AppTextRole.caption,
                          maxLines: 1,
                        ),
                      ),
                      IconButton(
                        tooltip: context.ui.copy,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.copy_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: text));
                        },
                      ),
                      AppDisclosureIcon(expanded: _expanded),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceSm,
                  0,
                  AppTheme.spaceSm,
                  AppTheme.spaceSm,
                ),
                child: SelectableText(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
