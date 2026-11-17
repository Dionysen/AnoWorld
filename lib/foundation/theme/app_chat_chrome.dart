import 'package:flutter/material.dart';

import 'app_chat_colors.dart';

/// Chat chrome shapes / fills aligned with NativeTavern Zephyr chat.
abstract final class AppChatChrome {
  /// Near-pill outer radius for the floating composer.
  static const double composerOuterRadius = 50;

  /// Default continuous bubble corner (NT default ~30).
  static const double bubbleCornerRadius = 30;

  /// Content column max width on wide screens.
  static const double contentMaxWidth = 900;

  static Color composerFill(ColorScheme scheme, Brightness brightness) {
    return brightness == Brightness.dark
        ? Color.lerp(Colors.black, scheme.surface, 0.1)!
        : Color.lerp(Colors.white, scheme.surface, 0.06)!;
  }

  static List<BoxShadow> composerShadows(
    Brightness brightness, {
    double opacity = 1.0,
  }) {
    final o = opacity.clamp(0.0, 1.0);
    final color = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.35 * o)
        : Colors.black.withValues(alpha: 0.1 * o);
    return [
      BoxShadow(
        color: color,
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> messageBubbleShadows(
    Brightness brightness, {
    double opacity = 1.0,
  }) {
    final o = opacity.clamp(0.0, 1.0);
    if (o <= 0) return const [];
    final color = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.28 * o)
        : Colors.black.withValues(alpha: 0.08 * o);
    return [
      BoxShadow(
        color: color,
        blurRadius: 10,
        offset: const Offset(0, 3),
        spreadRadius: -1,
      ),
    ];
  }

  static ShapeBorder composerShape() => ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(composerOuterRadius),
      );

  static ShapeDecoration composerShell(
    BuildContext context, {
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    final o = opacity.clamp(0.0, 1.0);
    final fill = composerFill(theme.colorScheme, theme.brightness);
    return ShapeDecoration(
      color: o >= 1.0 ? fill : fill.withValues(alpha: o),
      shadows: composerShadows(theme.brightness, opacity: o),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(composerOuterRadius),
      ),
    );
  }

  static InputDecoration composerFieldDecoration(
    BuildContext context, {
    String? hintText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      hintStyle: messageInputStyle(
        context,
        color: scheme.onSurfaceVariant,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  static BorderRadius bubbleBorderRadius({
    required bool isUser,
    double radius = bubbleCornerRadius,
  }) {
    final r = radius.clamp(0.0, 80.0);
    return BorderRadius.only(
      topLeft: Radius.circular(isUser ? r : 0),
      topRight: Radius.circular(isUser ? 0 : r),
      bottomLeft: Radius.circular(r),
      bottomRight: Radius.circular(r),
    );
  }

  static ShapeBorder messageBubbleShape({
    required bool isUser,
    double radius = bubbleCornerRadius,
  }) =>
      ContinuousRectangleBorder(
        borderRadius: bubbleBorderRadius(isUser: isUser, radius: radius),
      );

  /// User bubble fill: accent blended onto surface (NT Zephyr).
  static Color userBubbleFromAccent(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return Color.alphaBlend(
      scheme.primary.withValues(alpha: dark ? 0.28 : 0.18),
      scheme.surface,
    );
  }

  static Color userAvatarFill(ColorScheme scheme) =>
      scheme.primary.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.28 : 0.18,
      );

  static ShapeDecoration messageBubbleDecoration(
    BuildContext context, {
    required bool isUser,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = AppChatColors.of(context);
    final base =
        isUser ? userBubbleFromAccent(scheme) : chat.characterBubble;
    return ShapeDecoration(
      color: base,
      shadows: messageBubbleShadows(theme.brightness),
      shape: ContinuousRectangleBorder(
        borderRadius: bubbleBorderRadius(isUser: isUser),
      ),
    );
  }

  static Color bubbleTextColor(BuildContext context) =>
      AppChatColors.of(context).chatText;

  static Color dialogueTextColor(BuildContext context) =>
      AppChatColors.of(context).dialogueText;

  static FontWeight get dialogueFontWeight => FontWeight.bold;

  static double messageFontSize(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;

  static TextStyle messageInputStyle(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    const lineHeight = 1.4;
    return (base ?? const TextStyle(fontSize: 14, height: lineHeight)).copyWith(
      color: color ?? theme.colorScheme.onSurface,
      fontSize: messageFontSize(context),
      height: lineHeight,
    );
  }

  static TextStyle bubbleBodyStyle(BuildContext context) {
    return messageInputStyle(
      context,
      color: bubbleTextColor(context),
    );
  }
}
