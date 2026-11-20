import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:flutter_test/flutter_test.dart';

Beat _beat(String id, {String nodeId = 'n1'}) => Beat(
      id: id,
      nodeId: nodeId,
      scene: const Scene(),
      appearances: const [],
      lines: const [],
      choices: const [],
    );

void main() {
  test('turnsForNode counts only beats on that station', () {
    final session = BridgeSession(
      nodeId: 'n2',
      turnCount: 1,
      generatedBeats: [
        _beat('b_a'),
        _beat('b_b', nodeId: 'n2'),
        _beat('b_c'),
      ],
    );

    expect(session.turnsForNode('n1'), 2);
    expect(session.turnsForNode('n2'), 1);
    expect(session.turnsForNode('n3'), 0);
  });

  test('toJson / fromJson round-trips branchEdges; legacy omits them', () {
    final session = BridgeSession(
      nodeId: 'n1',
      turnCount: 2,
      summary: 's',
      generatedBeats: [_beat('a'), _beat('b')],
      branchEdges: const [
        BridgeBranchEdge(
          fromBeatId: 'a',
          choiceId: 'a_c0',
          toBeatId: 'b',
        ),
      ],
    );
    final again = BridgeSession.fromJson(session.toJson());
    expect(again.nodeId, 'n1');
    expect(again.turnCount, 2);
    expect(again.summary, 's');
    expect(again.generatedBeats.map((b) => b.id), ['a', 'b']);
    expect(again.branchEdges.single.toBeatId, 'b');
    expect(again.toBeatId('a', 'a_c0'), 'b');

    final legacy = BridgeSession.fromJson(<String, dynamic>{
      'nodeId': 'n1',
      'turnCount': 0,
      'generatedBeats': <dynamic>[],
    });
    expect(legacy.branchEdges, isEmpty);
  });

  test('pruneSubtree keeps sibling branches', () {
    final session = BridgeSession(
      nodeId: 'n1',
      generatedBeats: [
        _beat('root'),
        _beat('stay'),
        _beat('stay2'),
        _beat('node'),
        _beat('node2'),
      ],
      branchEdges: const [
        BridgeBranchEdge(
          fromBeatId: 'root',
          choiceId: 'c_stay',
          toBeatId: 'stay',
        ),
        BridgeBranchEdge(
          fromBeatId: 'stay',
          choiceId: 'c_more',
          toBeatId: 'stay2',
        ),
        BridgeBranchEdge(
          fromBeatId: 'root',
          choiceId: 'c_node',
          toBeatId: 'node',
        ),
        BridgeBranchEdge(
          fromBeatId: 'node',
          choiceId: 'c_n2',
          toBeatId: 'node2',
        ),
      ],
    );

    final pruned = session.pruneSubtree('stay');
    expect(pruned.generatedBeats.map((b) => b.id).toSet(), {
      'root',
      'node',
      'node2',
    });
    expect(
      pruned.branchEdges.map((e) => '${e.fromBeatId}->${e.toBeatId}').toSet(),
      {'root->node', 'node->node2'},
    );
  });

  test('withBeat and withBranchEdge upsert', () {
    var session = BridgeSession(nodeId: 'n1', generatedBeats: [_beat('a')]);
    session = session.withBeat(_beat('b')).withBranchEdge(
          fromBeatId: 'a',
          choiceId: 'c0',
          toBeatId: 'b',
        );
    expect(session.toBeatId('a', 'c0'), 'b');
    session = session.withBranchEdge(
      fromBeatId: 'a',
      choiceId: 'c0',
      toBeatId: 'b2',
    );
    expect(session.toBeatId('a', 'c0'), 'b2');
    expect(session.branchEdges, hasLength(1));
  });
}
