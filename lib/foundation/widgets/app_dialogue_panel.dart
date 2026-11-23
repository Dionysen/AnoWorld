import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_dialogue_chrome.dart';
import '../theme/app_ui_tokens.dart';

/// Frosted, fixed-height reading panel for stage dialogue.
///
/// Height comes from [lines] and [fontSize] alone, so advancing to the next
/// text page never resizes the box. [header] and [trailing] share one reserved
/// row above the body, which keeps narration (no speaker) the same height.
class AppDialoguePanel extends StatelessWidget {
  const AppDialoguePanel({
    super.key,
    required this.child,
    required this.lines,
    required this.fontSize,
    this.header,
    this.trailing,
    this.backgroundHex = '',
    this.opacity = AppDialogueChrome.defaultOpacity,
  });

  /// One page of body text, styled with [AppDialogueChrome.bodyStyle].
  final Widget child;
  final int lines;
  final double fontSize;

  /// Speaker name; the row stays reserved when null.
  final Widget? header;

  /// Right-hand slot in the header row (e.g. page counter).
  final Widget? trailing;

  /// `#RRGGBB` fill; empty follows the theme surface.
  final String backgroundHex;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = AppUiTokens.of(context).radius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDialogueChrome.blurSigma,
          sigmaY: AppDialogueChrome.blurSigma,
        ),
        child: ColoredBox(
          color: AppDialogueChrome.fill(
            context,
            backgroundHex: backgroundHex,
            opacity: opacity,
          ),
          child: Padding(
            padding: AppDialogueChrome.padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: AppDialogueChrome.headerHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: header ?? const SizedBox.shrink(),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
                SizedBox(
                  height: AppDialogueChrome.bodyHeight(lines, fontSize),
                  width: double.infinity,
                  child: ClipRect(
                    child: Align(alignment: Alignment.topLeft, child: child),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
