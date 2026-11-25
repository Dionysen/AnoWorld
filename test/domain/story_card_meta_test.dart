import 'package:anoworld/domain/models/story_card_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatCardDate formats unix seconds and keeps free text', () {
    expect(
      StoryCardMeta.formatCardDate(1704067200),
      matches(RegExp(r'^2024-01-0[12] \d{2}:\d{2}$')),
    );
    expect(StoryCardMeta.formatCardDate(0), '');
    expect(StoryCardMeta.formatCardDate(null), '');
    expect(
      StoryCardMeta.formatCardDate('2023-8-31 @14h 30m 0s 123ms'),
      '2023-8-31 @14h 30m 0s 123ms',
    );
  });
}
