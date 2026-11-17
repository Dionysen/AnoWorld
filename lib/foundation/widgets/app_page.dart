import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';
import '../theme/app_theme.dart';
import 'app_circle_button.dart';
import 'app_text.dart';

/// Page shell. Business screens compose this instead of a scaffold or app bar.
///
/// On desktop, [title] sits below the chrome band (24 / pageTitle) with [onBack]
/// on its left and [actions] on its right (same row as the title). On phone and
/// tablet, title, back, and [actions] stay in the band.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions = const [],
    this.onBack,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final String title;

  /// When set, replaces the plain [title] text (e.g. slide/fade switcher).
  final Widget? titleWidget;
  final Widget body;

  /// Trailing controls aligned with the page title (large-title row on desktop,
  /// chrome band on phone/tablet).
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  static bool get _desktopLargeTitle {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  /// Insert [AppTheme.spaceSm] between action widgets.
  ///
  /// Existing bare [SizedBox] spacers in [actions] are dropped so callers can
  /// list controls without hand-spacing.
  static List<Widget> spacedActions(List<Widget> actions) {
    final items = actions.where((w) => w is! SizedBox).toList(growable: false);
    if (items.length <= 1) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(width: AppTheme.spaceSm));
      out.add(items[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ImmersiveScope.metricsOf(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final titleSpacing = theme.appBarTheme.titleSpacing ?? 12;
    final barColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final titleStyle = (theme.appBarTheme.titleTextStyle ??
            theme.textTheme.titleMedium)
        ?.copyWith(
          color:
              theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        );
    final largeTitle = _desktopLargeTitle;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation:
          floatingActionButtonLocation ??
              FloatingActionButtonLocation.endFloat,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Never force a taller band than the viewport; shrink or hide instead
          // of overflowing when the window is squeezed.
          final barHeight = math.min(metrics.barHeight, constraints.maxHeight);
          final showBar = barHeight > 0;
          final showChromeRow =
              showBar && barHeight >= metrics.statusInset + 20;
          // Width left for the title row after chrome insets.
          final rowWidth = math.max(
            0.0,
            constraints.maxWidth -
                metrics.leadingInset -
                metrics.trailingInset,
          );
          final bodyArea = math.max(0.0, constraints.maxHeight - barHeight);
          final showLargeTitle = largeTitle && bodyArea >= 72;
          // Back in the chrome band only on phone/tablet; desktop puts it
          // beside the large title below.
          final showBarBack =
              !showLargeTitle && onBack != null && rowWidth >= 36;
          final showTitleText =
              !showLargeTitle && rowWidth >= (showBarBack ? 52 : 24);
          final titleReserve = metrics.leadingInset +
              titleSpacing +
              metrics.trailingInset +
              (showBarBack ? 36.0 : 0.0) +
              48;
          final showBarActions = !showLargeTitle &&
              actions.isNotEmpty &&
              rowWidth >= 48 &&
              constraints.maxWidth >= titleReserve;
          final showTitleActions =
              showLargeTitle && actions.isNotEmpty && constraints.maxWidth >= 120;
          final showTitleBack = showLargeTitle &&
              onBack != null &&
              constraints.maxWidth >= 72;

          Widget pageBody = body;
          if (showLargeTitle) {
            pageBody = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.spaceXs,
                    AppTheme.pagePadding,
                    AppTheme.spaceSm,
                  ),
                  child: Row(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        alignment: Alignment.centerLeft,
                        child: showTitleBack
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  right: AppTheme.spaceSm,
                                ),
                                child: AppCircleButton(
                                  icon: Icons.arrow_back,
                                  tooltip: '返回',
                                  onPressed: onBack,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: titleWidget ??
                            AppText(
                              title,
                              role: AppTextRole.pageTitle,
                              maxLines: 1,
                            ),
                      ),
                      if (showTitleActions) ...spacedActions(actions),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            );
          }

          return Column(
            children: [
              if (showBar)
                ColoredBox(
                  color: barColor,
                  child: SizedBox(
                    height: barHeight,
                    width: double.infinity,
                    child: showChromeRow
                        ? Padding(
                            padding: EdgeInsets.only(
                              top: math.min(
                                metrics.statusInset,
                                math.max(0, barHeight - 20),
                              ),
                              left: metrics.leadingInset +
                                  (showBarBack ? 0 : titleSpacing),
                              right: metrics.trailingInset,
                            ),
                            child: Row(
                              children: [
                                if (showBarBack)
                                  AppCircleButton(
                                    icon: Icons.arrow_back,
                                    tooltip: '返回',
                                    onPressed: onBack,
                                    size: 32,
                                    iconSize: 18,
                                  ),
                                if (showTitleText)
                                  Expanded(
                                    child: titleWidget ??
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: titleStyle,
                                        ),
                                  )
                                else
                                  const Spacer(),
                                if (showBarActions) ...spacedActions(actions),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              Expanded(
                child: Padding(
                  // Bottom inset stays in MediaQuery so floating chrome
                  // (capsule nav) can overlay while scroll bodies pad themselves.
                  padding: EdgeInsets.only(
                    left: media.padding.left,
                    right: media.padding.right,
                  ),
                  child: pageBody,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Standard padded scrollable page body.
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(AppTheme.pagePadding),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final mediaBottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = padding.resolve(Directionality.of(context));
        return SingleChildScrollView(
          padding: resolved.copyWith(
            bottom: resolved.bottom + mediaBottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}
