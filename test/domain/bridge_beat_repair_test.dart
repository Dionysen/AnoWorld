import 'package:anoworld/domain/ai/bridge_beat_repair.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('narrationAsYou replaces longer names first', () {
    final out = BridgeBeatRepair.narrationAsYou(
      '旅人甲推门，旅人站着。',
      const ['旅人甲', '旅人'],
    );
    expect(out, '你推门，你站着。');
  });

  test('looksLikeObjectiveJump catches scene jumps but keeps agency', () {
    expect(BridgeBeatRepair.looksLikeObjectiveJump('来到大厅'), isTrue);
    expect(BridgeBeatRepair.looksLikeObjectiveJump('前往：客栈'), isTrue);
    expect(BridgeBeatRepair.looksLikeObjectiveJump('天黑了'), isTrue);
    expect(BridgeBeatRepair.looksLikeObjectiveJump('推门进去看看'), isFalse);
    expect(BridgeBeatRepair.looksLikeObjectiveJump('『这是怎么回事？』'), isFalse);
    expect(BridgeBeatRepair.looksLikeObjectiveJump('动身去客栈'), isFalse);
  });

  test('playerReferents includes aliases longest-first', () {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final project = blank.copyWith(
      cast: const [
        CastMember(id: 'c1', name: '瑞希', aliases: ['小瑞', 'R']),
      ],
    );
    final names = BridgeBeatRepair.playerReferents(
      project: project,
      role: const PlayRole(playerCastId: 'c1', aliases: ['User']),
    );
    expect(names.first, 'User'); // longest first (ASCII length)
    expect(names, containsAll(['瑞希', '小瑞', 'R', 'User']));
  });
}
