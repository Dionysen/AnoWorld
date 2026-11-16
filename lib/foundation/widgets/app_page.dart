import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';
import '../theme/app_theme.dart';
import 'app_circle_button.dart';
import 'app_icon_button.dart';
import 'app_text.dart';

/// Page shell. Business screens compose this instead of a scaffold or app bar.
///
/// On desktop, [title] sits below the chrome band (24 / pageTitle) with [onBack]
/// on its left; the band keeps actions only. On phone and tablet, title and
/// back stay in the band.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onBack;

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
          final showActions = actions.isNotEmpty &&
              rowWidth >= 48 &&
              constraints.maxWidth >= titleReserve;
          final showTitleBack = showLargeTitle &&
              onBack != null &&
              constraints.maxWidth >= 72;

          Widget pageBody = body;
          if (showLargeTitle) {
            pageBody = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    showTitleBack ? AppTheme.spaceSm : AppTheme.pagePadding,
                    AppTheme.spaceMd,
                    AppTheme.pagePadding,
                    AppTheme.spaceSm,
                  ),
                  child: Row(
                    children: [
                      if (showTitleBack) ...[
                        AppCircleButton(
                          icon: Icons.arrow_back,
                          tooltip: '返回',
                          onPressed: onBack,
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                      ],
                      Expanded(
                        child: AppText(
                          title,
                          role: AppTextRole.pageTitle,
                          maxLines: 1,
                        ),
                      ),
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
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    ),
                                  )
                                else
                                  const Spacer(),
                                if (showActions) ...actions,
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
