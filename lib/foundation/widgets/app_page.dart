import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';
import '../theme/app_theme.dart';
import 'app_icon_button.dart';

/// Page shell. Business screens compose this instead of a scaffold or app bar.
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Never force a taller band than the viewport; shrink or hide instead
          // of overflowing when the window is squeezed.
          final barHeight = math.min(metrics.barHeight, constraints.maxHeight);
          final showBar = barHeight > 0;
          final showTitle =
              showBar && barHeight >= metrics.statusInset + 20;
          // Width left for the title row after chrome insets.
          final rowWidth = math.max(
            0.0,
            constraints.maxWidth -
                metrics.leadingInset -
                metrics.trailingInset,
          );
          // Back needs ~36; hide it (and then the title) when the band is too
          // narrow instead of painting yellow/black overflow stripes.
          final showBack = onBack != null && rowWidth >= 36;
          final showTitleText = rowWidth >= (showBack ? 52 : 24);
          final titleReserve = metrics.leadingInset +
              titleSpacing +
              metrics.trailingInset +
              (showBack ? 36.0 : 0.0) +
              48;
          final showActions = actions.isNotEmpty &&
              showTitleText &&
              constraints.maxWidth >= titleReserve + 72;

          return Column(
            children: [
              if (showBar)
                ColoredBox(
                  color: barColor,
                  child: SizedBox(
                    height: barHeight,
                    width: double.infinity,
                    child: showTitle
                        ? Padding(
                            padding: EdgeInsets.only(
                              top: math.min(
                                metrics.statusInset,
                                math.max(0, barHeight - 20),
                              ),
                              left: metrics.leadingInset +
                                  (showBack ? 0 : titleSpacing),
                              right: metrics.trailingInset,
                            ),
                            child: Row(
                              children: [
                                if (showBack)
                                  AppIconButton(
                                    icon: Icons.arrow_back,
                                    tooltip: '返回',
                                    onPressed: onBack,
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
                  padding: EdgeInsets.only(
                    left: media.padding.left,
                    right: media.padding.right,
                    bottom: media.padding.bottom,
                  ),
                  child: body,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
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
