import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:flutter/material.dart';

/// Built-in kind colors for station headers (stable, not theme-tied).
abstract final class StoryNodeKindStyle {
  static const Color opening = Color(0xFF2A9B9F);
  static const Color scene = Color(0xFF4A6FA5);
  static const Color turning = Color(0xFFC47A2C);
  static const Color ending = Color(0xFF7C5CBF);

  static Color color(StoryNodeKind kind) => switch (kind) {
        StoryNodeKind.opening => opening,
        StoryNodeKind.scene => scene,
        StoryNodeKind.turning => turning,
        StoryNodeKind.ending => ending,
      };

  /// Kept for call sites that still pass [BuildContext]; color is fixed.
  static Color colorOf(BuildContext context, StoryNodeKind kind) => color(kind);
}
