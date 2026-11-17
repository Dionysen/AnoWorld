import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import '../theme/app_chat_chrome.dart';
import '../theme/app_theme.dart';

/// Floating pill composer (NativeTavern ChatComposer chrome).
///
/// Left: optional leading actions. Right: send / stop. Field is borderless.
class AppChatComposer extends StatelessWidget {
  const AppChatComposer({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '输入消息',
    this.isGenerating = false,
    this.enabled = true,
    this.onSend,
    this.onStop,
    this.leading,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final bool isGenerating;
  final bool enabled;
  final VoidCallback? onSend;
  final VoidCallback? onStop;

  /// Compact tools on the left of the action row (NT tune / model cluster).
  final List<Widget>? leading;

  static bool get _isDesktop {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  void _submit() {
    if (isGenerating) {
      onStop?.call();
      return;
    }
    onSend?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: DecoratedBox(
        decoration: AppChatChrome.composerShell(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled && !isGenerating,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: _isDesktop
                    ? TextInputAction.send
                    : TextInputAction.newline,
                onSubmitted: _isDesktop ? (_) => _submit() : null,
                style: AppChatChrome.messageInputStyle(context),
                decoration: AppChatChrome.composerFieldDecoration(
                  context,
                  hintText: hintText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
              child: Row(
                children: [
                  if (leading != null && leading!.isNotEmpty) ...[
                    ..._withGaps(leading!),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  Tooltip(
                    message: isGenerating ? '停止' : '发送',
                    child: Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: enabled ? _submit : null,
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: isGenerating
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: scheme.onPrimary,
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                    child: const SizedBox(
                                      width: 12,
                                      height: 12,
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: scheme.onPrimary,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _withGaps(List<Widget> children) {
    if (children.isEmpty) return const [];
    final out = <Widget>[children.first];
    for (var i = 1; i < children.length; i++) {
      out.add(const SizedBox(width: AppTheme.spaceSm));
      out.add(children[i]);
    }
    return out;
  }
}

/// Compact composer tool icon matching NT ChromeIconButton density.
class AppChatComposerIconButton extends StatelessWidget {
  const AppChatComposerIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        icon: Icon(
          icon,
          size: 22,
          color: selected ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}
