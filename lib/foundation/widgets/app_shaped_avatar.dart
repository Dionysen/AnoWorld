import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Leading avatar with circle / square / portrait shapes.
class AppShapedAvatar extends StatelessWidget {
  const AppShapedAvatar({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.backgroundColor,
  });

  final double width;
  final double height;
  final Widget child;
  final BoxShape shape;
  final double? borderRadius;
  final Color? backgroundColor;

  factory AppShapedAvatar.fromGeometry({
    Key? key,
    required double width,
    required AppAvatarGeometry geometry,
    required Widget child,
    Color? backgroundColor,
  }) {
    return AppShapedAvatar(
      key: key,
      width: width,
      height: geometry.heightFor(width),
      shape: geometry.boxShape,
      borderRadius: geometry.radiusFor(width),
      backgroundColor: backgroundColor,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? scheme.primary.withValues(alpha: 0.18);
    final radius = borderRadius ?? (shape == BoxShape.circle ? width / 2 : 8);
    final content = ColoredBox(
      color: bg,
      child: Center(child: child),
    );
    return SizedBox(
      width: width,
      height: height,
      child: shape == BoxShape.circle
          ? ClipOval(child: content)
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: content,
            ),
    );
  }
}

/// Geometry for shaped avatars (circle / square / portrait rectangle).
enum AppAvatarGeometry {
  circle,
  square,
  rectangle,
}

extension AppAvatarGeometryX on AppAvatarGeometry {
  BoxShape get boxShape => switch (this) {
        AppAvatarGeometry.circle => BoxShape.circle,
        AppAvatarGeometry.square || AppAvatarGeometry.rectangle =>
          BoxShape.rectangle,
      };

  double heightFor(double width) => switch (this) {
        AppAvatarGeometry.circle || AppAvatarGeometry.square => width,
        AppAvatarGeometry.rectangle => width * 4 / 3,
      };

  double radiusFor(double width) => switch (this) {
        AppAvatarGeometry.circle => width / 2,
        AppAvatarGeometry.square || AppAvatarGeometry.rectangle =>
          AppTheme.radiusMd - 2,
      };
}
