import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';

/// Localized short label for a station kind (badge and picker).
String nodeKindLabel(AppStrings strings, StoryNodeKind kind) {
  return switch (kind) {
    StoryNodeKind.opening => strings.nodeKindOpening,
    StoryNodeKind.scene => strings.nodeKindScene,
    StoryNodeKind.turning => strings.nodeKindTurning,
    StoryNodeKind.ending => strings.nodeKindEnding,
  };
}
