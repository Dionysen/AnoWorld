import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:flutter/material.dart';

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

    return Scaffold(
      body: Column(
        children: [
          ColoredBox(
            color: theme.colorScheme.surface,
            child: SizedBox(
              height: metrics.barHeight,
              child: Padding(
                padding: EdgeInsets.only(
                  top: metrics.statusInset,
                  left: metrics.leadingInset,
                  right: metrics.trailingInset,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
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
