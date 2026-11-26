import 'package:anoworld/domain/ai/novel_text_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scope keeps short text intact', () {
    const chunker = NovelTextChunker(maxTotalChars: 100);
    final scope = chunker.scope('短文');
    expect(scope.truncated, isFalse);
    expect(scope.usedChars, 2);
    expect(scope.totalChars, 2);
    expect(scope.text, '短文');
  });

  test('scope truncates over maxTotalChars', () {
    const chunker = NovelTextChunker(maxTotalChars: 10);
    final scope = chunker.scope('一二三四五六七八九十多余');
    expect(scope.truncated, isTrue);
    expect(scope.usedChars, 10);
    expect(scope.totalChars, greaterThan(10));
    expect(scope.text.length, 10);
  });

  test('chunk slides with overlap', () {
    const chunker = NovelTextChunker(
      maxTotalChars: 1000,
      windowChars: 10,
      overlapChars: 2,
    );
    // 26 chars → windows of 10 with step 8 → 3 chunks.
    final chunks = chunker.chunk('abcdefghijklmnopqrstuvwxyz');
    expect(chunks.length, 3);
    expect(chunks.first.length, 10);
    expect(chunks[1], startsWith(chunks[0].substring(8)));
    expect(chunks.last, endsWith('z'));
  });

  test('prepare scopes then chunks', () {
    const chunker = NovelTextChunker(
      maxTotalChars: 12,
      windowChars: 5,
      overlapChars: 1,
    );
    final prepared = chunker.prepare('abcdefghijklmnop');
    expect(prepared.scope.truncated, isTrue);
    expect(prepared.scope.text.length, 12);
    expect(prepared.chunks, isNotEmpty);
    expect(prepared.chunks.join().contains('m'), isFalse); // truncated away
  });

  test('empty input yields empty chunks', () {
    const chunker = NovelTextChunker();
    expect(chunker.chunk('   '), isEmpty);
    expect(chunker.prepare('').chunks, isEmpty);
  });
}
