import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full encode/decode round-trips sample', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final raw = MainGraphDocument.encodeJson(main);
    final back = MainGraphDocument.decodeJson(raw);
    expect(back.startNodeId, main.startNodeId);
    expect(back.nodes.length, main.nodes.length);
    expect(back.edges.length, main.edges.length);
    expect(back.beats.length, main.beats.length);
    expect(back.nodeById('n1')!.title, main.nodeById('n1')!.title);
  });

  test('skeleton omits beats and round-trips graph', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final skeleton = MainGraphDocument.encodeSkeleton(main);
    expect(skeleton['format'], MainGraphDocument.skeletonFormat);
    expect(skeleton.containsKey('beats'), isFalse);
    expect((skeleton['nodes'] as List).length, main.nodes.length);

    final back = MainGraphDocument.decodeSkeleton(skeleton);
    expect(back.beats, isEmpty);
    expect(back.nodes.length, main.nodes.length);
    expect(back.edges.length, main.edges.length);
    expect(back.startNodeId, main.startNodeId);

    final again = MainGraphDocument.decodeSkeletonJson(
      MainGraphDocument.encodeSkeletonJson(back),
    );
    expect(again.nodes.map((n) => n.id), back.nodes.map((n) => n.id));
  });

  test('decodeSkeleton accepts full main maps', () {
    final main = const ProjectFactory().createRainNightSample().main;
    final back = MainGraphDocument.decodeSkeleton(main.toJson());
    expect(back.beats.length, main.beats.length);
  });
}
