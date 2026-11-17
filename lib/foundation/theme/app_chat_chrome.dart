import 'package:flutter/material.dart';

import 'app_chat_colors.dart';
import 'app_ui_tokens.dart';

/// Chat chrome shapes / fills aligned with NativeTavern Zephyr chat.
abstract final class AppChatChrome {
  /// Near-pill outer radius for the floating composer.
  static const double composerOuterRadius = 50;

  /// Default continuous bubble corner (NT default ~30).
  static const double bubbleCornerRadius = 30;

  /// Content column max width on wide screens.
  static const double contentMaxWidth = 900;

  /// Bubble body line height (NT `chatLineHeight` default).
  static const double defaultLineHeight = 1.4;
  static const double minLineHeight = 1.0;
  static const double maxLineHeight = 2.5;
  static const double lineHeightStep = 0.05;

  /// Gap between blank-line paragraphs inside a bubble (NT default 8).
  static const double defaultParagraphSpacing = 8;
  static const double minParagraphSpacing = 0;
  static const double maxParagraphSpacing = 24;
  static const double paragraphSpacingStep = 1;

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
    bool narration = false,
    double radius = bubbleCornerRadius,
  }) {
    final r = radius.clamp(0.0, 80.0);
    if (narration) {
      return BorderRadius.circular(r);
    }
    return BorderRadius.only(
      topLeft: Radius.circular(isUser ? r : 0),
      topRight: Radius.circular(isUser ? 0 : r),
      bottomLeft: Radius.circular(r),
      bottomRight: Radius.circular(r),
    );
  }

  static ShapeBorder messageBubbleShape({
    required bool isUser,
    bool narration = false,
    double radius = bubbleCornerRadius,
  }) =>
      ContinuousRectangleBorder(
        borderRadius: bubbleBorderRadius(
          isUser: isUser,
          narration: narration,
          radius: radius,
        ),
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
    bool narration = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = AppChatColors.of(context);
    final Color base;
    if (narration) {
      base = Color.alphaBlend(
        scheme.onSurface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.08 : 0.06,
        ),
        chat.characterBubble,
      );
    } else if (isUser) {
      base = userBubbleFromAccent(scheme);
    } else {
      base = chat.characterBubble;
    }
    return ShapeDecoration(
      color: base,
      shadows: messageBubbleShadows(theme.brightness),
      shape: ContinuousRectangleBorder(
        borderRadius: bubbleBorderRadius(
          isUser: isUser,
          narration: narration,
        ),
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

  static TextStyle messageInputStyle(
    BuildContext context, {
    Color? color,
    double lineHeight = defaultLineHeight,
  }) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    final height = lineHeight.clamp(minLineHeight, maxLineHeight);
    return (base ?? TextStyle(fontSize: 14, height: height)).copyWith(
      color: color ?? theme.colorScheme.onSurface,
      fontSize: messageFontSize(context),
      height: height,
    );
  }

  static TextStyle bubbleBodyStyle(
    BuildContext context, {
    double lineHeight = defaultLineHeight,
  }) {
    return messageInputStyle(
      context,
      color: bubbleTextColor(context),
      lineHeight: lineHeight,
    );
  }

  /// Subtle fill for reply-choice chips (NT Zephyr menuChip).
  static Color menuChipFill(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.07 : 0.05);
  }

  static BoxDecoration menuChip(
    BuildContext context, {
    bool showBorder = true,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = AppUiTokens.of(context).radius;
    return BoxDecoration(
      color: showBorder ? menuChipFill(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      border: showBorder
          ? Border.all(
              color: scheme.outlineVariant
                  .withValues(alpha: isDark ? 0.28 : 0.35),
            )
          : null,
    );
  }

  /// Chip control with Material ink (reply options).
  static Widget tappableMenuChip(
    BuildContext context, {
    required VoidCallback? onTap,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool showBorder = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(AppUiTokens.of(context).radius);
    return Material(
      color: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashFactory: InkRipple.splashFactory,
        splashColor: scheme.primary.withValues(alpha: 0.14),
        highlightColor: scheme.onSurface.withValues(alpha: 0.06),
        child: Ink(
          decoration: menuChip(context, showBorder: showBorder),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}
