import 'dart:math' as math;
import 'dart:ui';

import 'package:anoworld/home/create_assistant_bloom_outline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('openReference outline is finite and non-empty', () {
    final path = CreateAssistantBloomOutline.openReference();
    final bounds = path.getBounds();
    expect(bounds.width, greaterThan(100));
    expect(bounds.height, greaterThan(100));
    expect(path.computeMetrics().length, 1);
    expectSmooth(path);
  });

  test('collapsed metrics yield a circle', () {
    const a = CreateAssistantBloomOutline.designAnchor;
    final path = CreateAssistantBloomOutline.build(
      const CreateAssistantBloomMetrics(
        width: a,
        panelHeight: 0,
        neckGap: 0,
        anchor: a,
        cornerRadius: a / 2,
      ),
    );
    final bounds = path.getBounds();
    expect(bounds.width, closeTo(a, 1));
    expect(bounds.height, closeTo(a, 1));
    expect(path.contains(const Offset(a / 2, a / 2)), isTrue);
    expect(path.contains(const Offset(2, 2)), isFalse);
    expectSmooth(path);
  });

  test('open outline spans panel, neck, and anchor', () {
    const w = 420.0;
    const h = 520.0;
    const a = CreateAssistantBloomOutline.designAnchor;
    const g = CreateAssistantBloomOutline.designNeckGap;
    final metrics = CreateAssistantBloomMetrics(
      width: w,
      panelHeight: h,
      neckGap: g,
      anchor: a,
      cornerRadius: 16,
    );
    final path = CreateAssistantBloomOutline.build(metrics);
    final bounds = path.getBounds();
    expect(bounds.left, greaterThan(-1.5));
    expect(bounds.top, greaterThan(-1.5));
    expect(bounds.bottom, greaterThan(h + g + a * 0.9));
    final contour = path.computeMetrics().single;
    var maxX = 0.0;
    var maxY = 0.0;
    for (var d = 0.0; d < contour.length; d += 1) {
      final tangent = contour.getTangentForOffset(d);
      if (tangent == null) continue;
      if (tangent.position.dx > maxX) maxX = tangent.position.dx;
      if (tangent.position.dy > maxY) maxY = tangent.position.dy;
    }
    expect(maxX, lessThan(w + 1.5));
    expect(maxY, closeTo(h + g + a, 1.5));

    final center = metrics.buttonCenter;
    expect(path.contains(Offset(w / 2, h / 2)), isTrue);
    expect(path.contains(center), isTrue);
    expect(
      path.contains(Offset(center.dx, center.dy + metrics.buttonRadius * 0.7)),
      isTrue,
    );
    expect(path.contains(Offset(24, h + g * 0.5)), isFalse);
    expect(
      path.contains(Offset(center.dx, center.dy + metrics.buttonRadius + 6)),
      isFalse,
    );
    expectSmooth(path);
  });

  test('open silhouette pinches between the panel and the anchor', () {
    const w = 420.0;
    const h = 520.0;
    const g = CreateAssistantBloomOutline.designNeckGap;
    final path = CreateAssistantBloomOutline.build(
      const CreateAssistantBloomMetrics(
        width: w,
        panelHeight: h,
        neckGap: g,
        anchor: CreateAssistantBloomOutline.designAnchor,
        cornerRadius: 16,
      ),
    );

    final gapWidths = <double, int>{
      for (var y = h + 1.0; y < h + g - 0.5; y += 1)
        y: _insideWidth(path, y, w),
    };
    final narrowest = gapWidths.values.reduce(math.min);
    expect(narrowest, inInclusiveRange(14, 30));
    expect(_insideWidth(path, h * 0.5, w), greaterThan(w - 8));

    final waistY = gapWidths.entries
        .firstWhere((entry) => entry.value == narrowest)
        .key;
    expect(path.contains(Offset(w - 2, waistY)), isFalse);
    expect(path.contains(Offset(w / 2, h * 0.5)), isTrue);
  });

  test('waist tightens as the bloom opens', () {
    int waist(double strength) {
      const w = 420.0;
      const h = 520.0;
      const g = CreateAssistantBloomOutline.designNeckGap;
      final path = CreateAssistantBloomOutline.build(
        const CreateAssistantBloomMetrics(
          width: w,
          panelHeight: h,
          neckGap: g,
          anchor: CreateAssistantBloomOutline.designAnchor,
          cornerRadius: 16,
        ),
        neckStrength: strength,
      );
      var narrowest = 1 << 20;
      for (var y = h + 1.0; y < h + g - 0.5; y += 1) {
        narrowest = math.min(narrowest, _insideWidth(path, y, w));
      }
      return narrowest;
    }

    expect(waist(1), lessThan(waist(0.35) - 4));
  });

  test('every bloom frame stays one smooth contour on the anchor', () {
    const anchor = CreateAssistantBloomOutline.designAnchor;
    const targetW = 400.0;
    const targetH = 520.0;
    const gapOpen = CreateAssistantBloomOutline.designNeckGap;
    const openRadius = 10.0;

    for (var step = 0; step <= 16; step++) {
      final u = step / 16;
      final panelW = anchor + (targetW - anchor) * u;
      final panelH = targetH * u;
      final neckGap = gapOpen * u;
      final metrics = CreateAssistantBloomMetrics(
        width: panelW,
        panelHeight: panelH,
        neckGap: neckGap,
        anchor: anchor,
        cornerRadius: anchor / 2 + (openRadius - anchor / 2) * u,
      );
      final path = CreateAssistantBloomOutline.build(metrics, neckStrength: u);
      expect(
        path.contains(metrics.buttonCenter),
        isTrue,
        reason: 'frame $u lost the anchor',
      );
      expect(path.computeMetrics(), hasLength(1), reason: 'frame $u');
      expectSmooth(path);
    }
  });

  test('early bloom stays one smooth blob on the anchor', () {
    const a = CreateAssistantBloomOutline.designAnchor;
    final metrics = CreateAssistantBloomMetrics(
      width: 96,
      panelHeight: 40,
      neckGap: 1.5,
      anchor: a,
      cornerRadius: 20,
    );
    final path = CreateAssistantBloomOutline.build(metrics, neckStrength: 0.12);
    expect(path.computeMetrics().length, 1);
    expect(path.contains(metrics.buttonCenter), isTrue);
    expect(
      path.contains(
        Offset(
          metrics.buttonCenter.dx,
          metrics.buttonCenter.dy + metrics.buttonRadius * 0.55,
        ),
      ),
      isTrue,
    );
    final contour = path.computeMetrics().single;
    var maxX = 0.0;
    var maxY = 0.0;
    for (var d = 0.0; d < contour.length; d += 2) {
      final tangent = contour.getTangentForOffset(d);
      if (tangent == null) continue;
      if (tangent.position.dx > maxX) maxX = tangent.position.dx;
      if (tangent.position.dy > maxY) maxY = tangent.position.dy;
    }
    expect(maxX, lessThan(metrics.width + 1.5));
    expect(maxY, lessThan(metrics.totalHeight + 1.5));
    expectSmooth(path);
  });
}

int _insideWidth(Path path, double y, double width) {
  var count = 0;
  for (var x = 0.5; x < width; x += 1) {
    if (path.contains(Offset(x, y))) count++;
  }
  return count;
}

void expectSmooth(Path path) {
  final metrics = path.computeMetrics().toList();
  expect(metrics, hasLength(1));
  final metric = metrics.single;
  Offset? previous;
  for (var distance = 0.0; distance < metric.length; distance += 4) {
    final tangent = metric.getTangentForOffset(distance);
    if (tangent == null || tangent.vector.distance < 0.2) continue;
    final vector = tangent.vector;
    if (previous != null) {
      final dot =
          (previous.dx * vector.dx + previous.dy * vector.dy) /
          (previous.distance * vector.distance);
      expect(dot, greaterThan(0.7), reason: 'kink near ${tangent.position}');
    }
    previous = vector;
  }
}
