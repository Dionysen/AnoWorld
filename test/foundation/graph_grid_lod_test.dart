import 'package:anoworld/foundation/graph/graph_grid_lod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('step keeps on-screen spacing near the target', () {
    for (final scale in <double>[0.4, 0.7, 1, 1.5, 2.5]) {
      final step = GraphGridLod.stepForScale(scale);
      final screen = step * scale;
      expect(
        screen,
        inInclusiveRange(
          GraphGridLod.targetScreenPx * 0.5,
          GraphGridLod.targetScreenPx * 2.0,
        ),
        reason: 'scale=$scale step=$step screen=$screen',
      );
    }
  });

  test('step follows 1-2-5 series', () {
    expect(GraphGridLod.stepForScale(1), 20);
    expect(GraphGridLod.stepForScale(1.5), 20);
    expect(GraphGridLod.stepForScale(2), 20);
    expect(GraphGridLod.stepForScale(0.5), 50);
  });

  test('major index every fifth line', () {
    expect(GraphGridLod.isMajorIndex(0), isTrue);
    expect(GraphGridLod.isMajorIndex(5), isTrue);
    expect(GraphGridLod.isMajorIndex(1), isFalse);
    expect(GraphGridLod.isMajorIndex(4), isFalse);
  });
}
