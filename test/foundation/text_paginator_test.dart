import 'package:anoworld/foundation/text/text_paginator.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const TextStyle _style = TextStyle(fontSize: 16, height: 1.5);

bool _fits(String text, double width, int maxLines) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _style),
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
  )..layout(maxWidth: width);
  return !painter.didExceedMaxLines;
}

void main() {
  test('short text stays one page', () {
    final pages = paginateText(
      '雨还在下。',
      style: _style,
      maxWidth: 240,
      maxLines: 3,
    );
    expect(pages, <String>['雨还在下。']);
  });

  test('empty text and unusable width stay one page', () {
    expect(
      paginateText('', style: _style, maxWidth: 240, maxLines: 3),
      <String>[''],
    );
    expect(
      paginateText('一段话', style: _style, maxWidth: 0, maxLines: 3),
      <String>['一段话'],
    );
  });

  test('long CJK text pages within the line budget', () {
    final text = '雨还在下，' * 40;
    final pages = paginateText(text, style: _style, maxWidth: 200, maxLines: 3);

    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      expect(page, isNotEmpty);
      expect(_fits(page, 200, 3), isTrue, reason: 'page overflows: $page');
    }
    // Punctuation breaks keep every character.
    expect(pages.join(), text);
  });

  test('cuts English text on word boundaries', () {
    const text =
        'The rain kept falling over the border town while the lanterns '
        'swayed and every rumour grew a little louder than the last.';
    final pages = paginateText(text, style: _style, maxWidth: 120, maxLines: 2);

    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      expect(_fits(page, 120, 2), isTrue, reason: 'page overflows: $page');
    }
    expect(pages.join().replaceAll(' ', ''), text.replaceAll(' ', ''));
  });

  test('respects the text scaler used by the page', () {
    final text = '雨还在下，' * 20;
    const scaled = TextScaler.linear(1.6);
    final pages = paginateText(
      text,
      style: _style,
      maxWidth: 200,
      maxLines: 3,
      textScaler: scaled,
    );

    for (final page in pages) {
      final painter = TextPainter(
        text: TextSpan(text: page, style: _style),
        textDirection: TextDirection.ltr,
        textScaler: scaled,
        maxLines: 3,
      )..layout(maxWidth: 200);
      expect(painter.didExceedMaxLines, isFalse, reason: 'page: $page');
    }
  });
}
