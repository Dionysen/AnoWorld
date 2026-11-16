import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromTags reads ending for legacy packs', () {
    expect(StoryNodeKind.fromTags(['ending']), StoryNodeKind.ending);
  });

  test('fromTags defaults to scene', () {
    expect(StoryNodeKind.fromTags(const []), StoryNodeKind.scene);
  });

  test('apply replaces previous kind tag', () {
    final next = StoryNodeKind.apply(['opening', 'misc'], StoryNodeKind.turning);
    expect(next, containsAll(['turning', 'misc']));
    expect(next, isNot(contains('opening')));
  });

  test('labels are user-facing', () {
    expect(StoryNodeKind.opening.label, '开场');
    expect(StoryNodeKind.ending.label, '结束');
  });
}
