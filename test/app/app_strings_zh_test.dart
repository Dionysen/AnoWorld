import 'package:anoworld/app/l10n/app_strings_zh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const zh = AppStringsZh();

  group('section size lines', () {
    test('world book shows counts and raw tokens', () {
      expect(zh.worldBookSize(12, 3, 4210), '12 条设定，3 条常驻，4210 token');
      expect(zh.worldBookSize(0, 0, 0), '还没有设定条目');
    });

    test('cast shows member count and raw tokens', () {
      expect(zh.castSize(2, 33), '2 个角色，33 token');
      expect(zh.castSize(0, 0), '还没有角色');
    });

    test('main line shows node count and raw tokens', () {
      expect(zh.mainSize(2, 37), '2 个节点，37 token');
      expect(zh.mainSize(0, 0), '还没有情节节点');
    });

    test('plot elements show selection and raw tokens', () {
      expect(zh.plotElementsSize(2, 4210), '已选 2 项，4210 token');
      expect(zh.plotElementsSize(0, 0), '还没选');
    });
  });

  test('count label reads as still empty at zero', () {
    expect(zh.countLabel(0), '还空着');
    expect(zh.countLabel(3), '3 条');
  });
}
