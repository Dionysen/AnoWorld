import 'package:anoworld/foundation/ai/think_tag_stream_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passes plain text through unchanged', () {
    final filter = ThinkTagStreamFilter();
    expect(filter.add('你好'), ('你好', ''));
    expect(filter.add('，世界'), ('，世界', ''));
    expect(filter.flush(), ('', ''));
  });

  test('splits an inline think block from the visible text', () {
    final filter = ThinkTagStreamFilter();
    expect(filter.add('<think>内心'), ('', '内心'));
    expect(filter.add('想法</think>正文'), ('正文', '想法'));
    expect(filter.flush(), ('', ''));
  });

  test('holds back half-written tags across chunks', () {
    final filter = ThinkTagStreamFilter();
    expect(filter.add('开场<thi'), ('开场', ''));
    expect(filter.add('nk>想'), ('', '想'));
    expect(filter.add('一下</thi'), ('', '一下'));
    expect(filter.add('nk>收尾'), ('收尾', ''));
  });

  test('flush releases a dangling tag start as plain text', () {
    final filter = ThinkTagStreamFilter();
    expect(filter.add('结尾<thi'), ('结尾', ''));
    expect(filter.flush(), ('<thi', ''));
  });
}
