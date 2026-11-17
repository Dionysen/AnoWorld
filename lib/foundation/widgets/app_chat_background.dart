import 'package:flutter/material.dart';

import '../theme/app_chat_background.dart';
import '../theme/app_chat_colors.dart';

/// Paints [background] under [child]; theme chat canvas always shows beneath.
class AppChatBackgroundLayer extends StatelessWidget {
  const AppChatBackgroundLayer({
    super.key,
    required this.background,
    required this.child,
  });

  final AppChatBackground background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = AppChatColors.of(context).background;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        if (background.kind != AppChatBackgroundKind.none)
          Positioned.fill(child: _Paint(background: background)),
        child,
      ],
    );
  }
}

class _Paint extends StatelessWidget {
  const _Paint({required this.background});

  final AppChatBackground background;

  @override
  Widget build(BuildContext context) {
    switch (background.kind) {
      case AppChatBackgroundKind.none:
        return const SizedBox.shrink();
      case AppChatBackgroundKind.color:
        return ColoredBox(
          color: AppChatBackground.parseHex(background.colorHex),
        );
      case AppChatBackgroundKind.gradient:
        final gradient = background.toGradient();
        if (gradient == null) return const SizedBox.shrink();
        return DecoratedBox(decoration: BoxDecoration(gradient: gradient));
    }
  }
}
