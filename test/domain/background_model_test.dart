import 'package:anoworld/domain/models/background.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads legacy sections as always-on entries', () {
    final background = Background.fromJson({
      'sections': [
        {'id': 'bg1', 'title': '世界观', 'body': '边城雨夜'},
      ],
    });
    expect(background.entries, hasLength(1));
    expect(background.entries.first.alwaysOn, isTrue);
    expect(background.entries.first.body, '边城雨夜');
  });

  test('round-trips entries with keys', () {
    const original = Background(
      entries: [
        BackgroundEntry(
          id: 'bg_keep',
          title: '基调',
          body: '雨夜边城',
          alwaysOn: true,
        ),
        BackgroundEntry(
          id: 'bg_inn',
          title: '客栈',
          body: '唯一歇脚处',
          keys: ['客栈', '掌柜'],
        ),
      ],
    );
    final restored = Background.fromJson(original.toJson());
    expect(restored.entries, hasLength(2));
    expect(restored.entries[1].keys, ['客栈', '掌柜']);
    expect(restored.alwaysOnText, contains('雨夜边城'));
  });
}
