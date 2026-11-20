import 'package:anoworld/foundation/ai/tolerant_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strict JSON is decoded untouched', () {
    final decoded = decodeTolerantJson('{"a":"他说\\"走\\"","b":[1,2]}');
    expect(decoded, isA<Map>());
    expect((decoded! as Map)['a'], '他说"走"');
  });

  test('unescaped quotes inside a Chinese value are repaired', () {
    // Shape DeepSeek really sends: the model quotes words without escaping.
    const raw = '{"ops":[{"op":"upsert_node","title":"入宗受辱",'
        '"synopsis":"陆昭入外门，同门唤他"扫地的"，连杂役峰的老仆都劝他下山。"}]}';
    final decoded = decodeTolerantJson(raw);
    expect(decoded, isA<Map>());
    final op = ((decoded! as Map)['ops'] as List).first as Map;
    expect(op['synopsis'], '陆昭入外门，同门唤他"扫地的"，连杂役峰的老仆都劝他下山。');
  });

  test('a quote before a JSON delimiter still closes the string', () {
    const raw = '{"title":"他说"好"", "synopsis":"收尾。"}';
    final decoded = decodeTolerantJson(raw) as Map?;
    expect(decoded, isNotNull);
    expect(decoded!['title'], '他说"好"');
    expect(decoded['synopsis'], '收尾。');
  });

  test('raw line breaks inside a value are escaped', () {
    final decoded = decodeTolerantJson('{"body":"第一行\n第二行"}') as Map?;
    expect(decoded, isNotNull);
    expect(decoded!['body'], '第一行\n第二行');
  });

  test('truncated output still fails instead of inventing data', () {
    const raw = '{"ops":[{"op":"upsert_node","title":"没写完的站","synopsis":"写到一半';
    expect(decodeTolerantJson(raw), isNull);
  });

  test('non-object JSON is not silently accepted as arguments', () {
    expect(decodeTolerantJson('[1,2,3]'), isA<List>());
    expect(decodeTolerantJson('不是 JSON'), isNull);
  });
}
