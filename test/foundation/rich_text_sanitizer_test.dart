import 'package:anoworld/foundation/text/rich_text_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sanitizer = RichTextSanitizer();

  test('strips br and bold html', () {
    const raw = 'Hello<br/><b>world</b>';
    final out = sanitizer.sanitize(raw);
    expect(out, contains('Hello'));
    expect(out, contains('**world**'));
    expect(RichTextSanitizer.containsHtmlTag(out), isFalse);
  });

  test('preserves fenced markdown code', () {
    const md = 'Intro\n```dart\nvoid main() {}\n```\n';
    expect(sanitizer.sanitize(md), md.trim());
  });

  test('converts pre block to fenced code', () {
    const raw = '<pre><code>line1\nline2</code></pre>';
    final out = sanitizer.sanitize(raw);
    expect(out, contains('```'));
    expect(out, contains('line1'));
    expect(RichTextSanitizer.containsHtmlTag(out), isFalse);
  });

  test('idempotent on clean markdown', () {
    const md = '- item\n\n**bold** and `code`';
    final once = sanitizer.sanitize(md);
    final twice = sanitizer.sanitize(once);
    expect(twice, once);
  });

  test('decode entities', () {
    expect(sanitizer.sanitize('a&nbsp;b'), 'a b');
  });
}