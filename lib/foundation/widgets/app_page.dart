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
    final barColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          ColoredBox(
            color: barColor,
            child: SizedBox(
              height: metrics.barHeight,
              child: Padding(
                padding: EdgeInsets.only(
                  top: metrics.statusInset,
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
                        style: (theme.appBarTheme.titleTextStyle ??
                                theme.textTheme.titleMedium)
                            ?.copyWith(
                              color:
                                  theme.appBarTheme.foregroundColor ??
                                  theme.colorScheme.onSurface,
                            ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
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
      ),
    );
  }
}
