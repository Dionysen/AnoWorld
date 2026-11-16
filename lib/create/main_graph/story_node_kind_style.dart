import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:flutter/material.dart';

/// Theme mapping for station kind color bars (create UI only).
abstract final class StoryNodeKindStyle {
  static Color color(BuildContext context, StoryNodeKind kind) {
    final scheme = Theme.of(context).colorScheme;
    return switch (kind) {
      StoryNodeKind.opening => scheme.tertiary,
      StoryNodeKind.scene => scheme.outline,
      StoryNodeKind.turning => scheme.primary,
      StoryNodeKind.ending => scheme.secondary,
    };
  }
}
