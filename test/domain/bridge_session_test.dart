import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('turnsForNode counts only beats on that station', () {
    const session = BridgeSession(
      nodeId: 'n2',
      turnCount: 1,
      generatedBeats: [
        Beat(
          id: 'b_a',
          nodeId: 'n1',
          scene: Scene(),
          appearances: [],
          lines: [],
          choices: [],
        ),
        Beat(
          id: 'b_b',
          nodeId: 'n2',
          scene: Scene(),
          appearances: [],
          lines: [],
          choices: [],
        ),
        Beat(
          id: 'b_c',
          nodeId: 'n1',
          scene: Scene(),
          appearances: [],
          lines: [],
          choices: [],
        ),
      ],
    );

    expect(session.turnsForNode('n1'), 2);
    expect(session.turnsForNode('n2'), 1);
    expect(session.turnsForNode('n3'), 0);
  });
}
