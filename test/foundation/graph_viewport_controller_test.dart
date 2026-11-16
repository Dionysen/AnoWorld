import 'package:anoworld/foundation/graph/graph_viewport_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setVisibleSceneTopLeft moves visible rect', () {
    final camera = GraphViewportController();
    addTearDown(camera.dispose);
    camera.viewportSize = const Size(400, 300);
    camera.transform.value = Matrix4.identity();

    camera.transform.value = Matrix4.identity()
      ..scaleByDouble(2.0, 2.0, 1, 1);
    final zoomed = camera.visibleSceneRect!;
    expect(zoomed.width / zoomed.height, closeTo(400 / 300, 0.01));

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
}