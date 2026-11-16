import 'package:anoworld/create/main_graph/story_node_kind_style.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each kind has a distinct built-in color', () {
    final colors = {
      for (final kind in StoryNodeKind.values)
        kind: StoryNodeKindStyle.color(kind),
    };
    expect(colors.values.toSet().length, StoryNodeKind.values.length);
    expect(colors[StoryNodeKind.opening], StoryNodeKindStyle.opening);
    expect(colors[StoryNodeKind.scene], StoryNodeKindStyle.scene);
    expect(colors[StoryNodeKind.turning], StoryNodeKindStyle.turning);
    expect(colors[StoryNodeKind.ending], StoryNodeKindStyle.ending);
  });
}
