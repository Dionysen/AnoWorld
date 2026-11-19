import 'package:anoworld/foundation/text/token_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenEstimator.estimate', () {
    test('empty text is zero tokens', () {
      expect(TokenEstimator.estimate(''), 0);
    });

    test('four ASCII characters share one token', () {
      expect(TokenEstimator.estimate('abcd'), 1);
      expect(TokenEstimator.estimate('abcde'), 2);
      expect(TokenEstimator.estimate('Hello world'), 3);
    });

    test('each CJK character costs one token', () {
      expect(TokenEstimator.estimate('你好世界'), 4);
    });

    test('mixed scripts add up', () {
      // 4 CJK + 4 ASCII = 4 + 1.
      expect(TokenEstimator.estimate('中文测试abcd'), 5);
    });
  });
}
