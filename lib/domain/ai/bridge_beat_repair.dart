import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/play_role.dart';

/// Light post-parse fixes so VN beats stay second-person and player-agency.
abstract final class BridgeBeatRepair {
  /// Names the player may be called as (cast name + aliases), longest first.
  static List<String> playerReferents({
    required Project project,
    required PlayRole role,
  }) {
    final player = role.playerIn(project);
    if (player == null) return const <String>[];
    final names = <String>{
      player.name.trim(),
      for (final a in player.aliases) a.trim(),
      for (final a in role.aliases) a.trim(),
    }..removeWhere((n) => n.isEmpty);
    final list = names.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return list;
  }

  /// In narration, replace the player's name/aliases with 「你」.
  static String narrationAsYou(String text, List<String> playerNames) {
    if (text.isEmpty || playerNames.isEmpty) return text;
    var out = text;
    for (final name in playerNames) {
      out = out.replaceAll(name, '你');
    }
    return out.replaceAll(RegExp(r'你{2,}'), '你');
  }

  /// True when choice text reads as an objective scene jump / time skip.
  static bool looksLikeObjectiveJump(String choiceText) {
    final t = choiceText.trim();
    if (t.isEmpty) return true;
    // Quoted speech is player dialogue.
    if (t.contains('「') ||
        t.contains('」') ||
        t.contains('『') ||
        t.contains('』') ||
        t.contains('"') ||
        t.contains("'")) {
      return false;
    }
    const badPrefixes = <String>[
      '来到',
      '前往',
      '抵达',
      '进入场景',
      '场景切换',
      '时间快进',
      '画面切到',
      '转场到',
      '跳到',
      '场景变为',
    ];
    for (final prefix in badPrefixes) {
      if (t.startsWith(prefix)) return true;
    }
    const badExact = <String>{
      '天黑了',
      '天亮了',
      '第二天',
      '不久后',
      '过了一会儿',
      '与此同时',
      '一段时间后',
    };
    if (badExact.contains(t)) return true;
    if (RegExp(r'^时间.+(到|至|快进)').hasMatch(t)) return true;
    return false;
  }

  /// Drops objective-jump choices; keeps player-agency wording.
  static List<Choice> filterAgencyChoices(List<Choice> choices) {
    return [
      for (final c in choices)
        if (!looksLikeObjectiveJump(c.text)) c,
    ];
  }

  /// Rewrites narration lines so the player is 「你」.
  static List<DialogueLine> repairLines({
    required List<DialogueLine> lines,
    required Project project,
    required PlayRole role,
  }) {
    final names = playerReferents(project: project, role: role);
    if (names.isEmpty) return lines;
    return [
      for (final line in lines)
        if (line.kind == DialogueKind.narration && line.speakerId == null)
          DialogueLine(
            id: line.id,
            text: narrationAsYou(line.text, names),
            kind: line.kind,
            speakerId: line.speakerId,
          )
        else
          line,
    ];
  }
}
