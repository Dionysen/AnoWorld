import 'package:anoworld/domain/card_import/card_sanitize_action.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleans creator notes in card metadata', () {
    const draft = StCardImportDraft(
      title: '柜',
      castItems: [],
      worldBookItems: [],
      cardMeta: StoryCardMeta(creatorNotes: '<b>原作者的说明</b>'),
    );

    final result = const CardSanitizeAction().run(draft);

    expect(result.draft.cardMeta.creatorNotes, '**原作者的说明**');
    expect(result.changedFieldCount, 1);
    expect(result.samples.single.label, '作者注');
  });

  test('leaves already plain creator notes alone', () {
    const draft = StCardImportDraft(
      title: '柜',
      castItems: [],
      worldBookItems: [],
      cardMeta: StoryCardMeta(creatorNotes: '干净的说明'),
    );

    final result = const CardSanitizeAction().run(draft);

    expect(result.changedFieldCount, 0);
    expect(result.samples, isEmpty);
  });
}
