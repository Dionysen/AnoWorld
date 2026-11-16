import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';

/// Page shell. Business screens compose this instead of a scaffold or app bar.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

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
          final titleReserve =
              metrics.leadingInset + titleSpacing + metrics.trailingInset + 48;
          final showActions =
              actions.isNotEmpty && constraints.maxWidth >= titleReserve + 72;

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
                              left: metrics.leadingInset + titleSpacing,
                              right: metrics.trailingInset,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle,
                                  ),
                                ),
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
