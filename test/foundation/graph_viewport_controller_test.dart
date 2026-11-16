import 'package:anoworld/foundation/graph/graph_viewport_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setVisibleSceneTopLeft moves visible rect', () {
    final camera = GraphViewportController();
    addTearDown(camera.dispose);
    camera.viewportSize = const Size(400, 300);
    camera.transform.value = Matrix4.identity()
      ..scaleByDouble(1.0, 1.0, 1, 1);

    camera.setVisibleSceneTopLeft(const Offset(100, 50));
    final rect = camera.visibleSceneRect!;
    expect(rect.left, closeTo(100, 0.5));
    expect(rect.top, closeTo(50, 0.5));
    expect(rect.width, closeTo(400, 0.5));
    expect(rect.height, closeTo(300, 0.5));

    camera.panVisibleByScene(const Offset(20, 10));
    final next = camera.visibleSceneRect!;
    expect(next.left, closeTo(120, 0.5));
    expect(next.top, closeTo(60, 0.5));
  });

  test('panVisibleByScene keeps zoom', () {
    final camera = GraphViewportController();
    addTearDown(camera.dispose);
    camera.viewportSize = const Size(400, 300);
    // Mimic InteractiveViewer: translate then scale (pinch around a point).
    camera.transform.value = Matrix4.identity()
      ..translateByDouble(80, 40, 0, 1)
      ..scaleByDouble(2.0, 2.0, 1, 1);

    final before = camera.scale;
    final rectBefore = camera.visibleSceneRect!;
    camera.panVisibleByScene(const Offset(16, 8));
    expect(camera.scale, closeTo(before, 0.001));
    final rectAfter = camera.visibleSceneRect!;
    expect(rectAfter.width, closeTo(rectBefore.width, 0.5));
    expect(rectAfter.height, closeTo(rectBefore.height, 0.5));
    expect(rectAfter.left, closeTo(rectBefore.left + 16, 0.5));
    expect(rectAfter.top, closeTo(rectBefore.top + 8, 0.5));
  });
}
