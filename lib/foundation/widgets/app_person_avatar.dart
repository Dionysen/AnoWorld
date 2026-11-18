import 'package:flutter/material.dart';

import 'app_shaped_avatar.dart';

/// Circular person silhouette avatar (WeChat Reading–style profile chip).
class AppPersonAvatar extends StatelessWidget {
  const AppPersonAvatar({
    super.key,
    this.size = 48,
    this.semanticLabel,
  });

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Colors.white : scheme.surfaceContainerHighest;
    final fg = dark ? const Color(0xFF1A1A1A) : scheme.onSurfaceVariant;
    final avatar = AppShapedAvatar(
      width: size,
      height: size,
      backgroundColor: bg,
      child: Icon(
        Icons.person,
        size: size * 0.62,
        color: fg,
      ),
    );
    final label = semanticLabel;
    if (label == null || label.isEmpty) return avatar;
    return Semantics(
      label: label,
      image: true,
      child: avatar,
    );
  }
}
