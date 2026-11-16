import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

/// Maps model JSON blobs into domain layers for staged create.
class StageResultMapper {
  const StageResultMapper();

  Background backgroundFromRaw(String raw) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const StageMapException('设定结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final sectionsRaw = map['sections'];
    if (sectionsRaw is! List || sectionsRaw.isEmpty) {
      throw const StageMapException('设定里没有可用的段落');
    }
    final sections = <BackgroundSection>[];
    for (var i = 0; i < sectionsRaw.length; i++) {
      final item = sectionsRaw[i];
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final title = _stringOf(row['title']) ?? '设定';
      final body = _stringOf(row['body']) ?? '';
      if (body.trim().isEmpty) continue;
      sections.add(
        BackgroundSection(
          id: _stringOf(row['id']) ?? 'bg_$i',
          title: title.trim(),
          body: body.trim(),
        ),
      );
    }
    if (sections.isEmpty) {
      throw const StageMapException('设定里没有可用的段落');
    }
    return Background(sections: sections);
  }

  List<CastMember> castFromRaw(String raw) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const StageMapException('角色结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final list = map['cast'];
    if (list is! List || list.isEmpty) {
      throw const StageMapException('没有可用的角色');
    }
    final cast = <CastMember>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final name = _stringOf(row['name'])?.trim() ?? '';
      if (name.isEmpty) continue;
      cast.add(
        CastMember(
          id: _stringOf(row['id']) ?? 'c_$i',
          name: name,
          summary: _stringOf(row['summary'])?.trim() ?? '',
          personality: _stringOf(row['personality'])?.trim() ?? '',
          speechStyle: _stringOf(row['speechStyle'])?.trim() ?? '',
          exampleLines: _stringList(row['exampleLines']),
        ),
      );
    }
    if (cast.isEmpty) {
      throw const StageMapException('没有可用的角色');
    }
    return cast;
  }

  /// Builds a short playable [MainStory] from AI JSON + current cast names.
  MainStory mainFromRaw(String raw, {required List<CastMember> cast}) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const StageMapException('情节结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final summary = _stringOf(map['summary'])?.trim() ?? '';
    final scenesRaw = map['scenes'];
    if (scenesRaw is! List || scenesRaw.isEmpty) {
      throw const StageMapException('情节里没有可用的场景');
    }

    final sceneMaps = <Map<String, dynamic>>[];
    for (final item in scenesRaw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final title = _stringOf(row['title'])?.trim();
      if (title == null || title.isEmpty) continue;
      sceneMaps.add(row);
    }
    if (sceneMaps.isEmpty) {
      throw const StageMapException('情节里没有可用的场景');
    }

    final nameToId = <String, String>{
      for (final member in cast) member.name: member.id,
    };

    final nodes = <StoryNode>[];
    final beats = <Beat>[];
    final edges = <StoryEdge>[];

    for (var i = 0; i < sceneMaps.length; i++) {
      final row = sceneMaps[i];
      final nodeId = 'n_${i + 1}';
      final beatId = 'b_${i + 1}';
      final title = _stringOf(row['title'])!.trim();
      final isLast = i == sceneMaps.length - 1;

      final lines = _parseLines(row['lines'], sceneIndex: i, nameToId: nameToId);
      if (lines.isEmpty) {
        lines.add(
          DialogueLine(
            id: 'l_${i + 1}_0',
            text: title,
            kind: DialogueKind.narration,
          ),
        );
      }

      final appearances = _appearancesFor(
        lines: lines,
        speakersHint: row['speakers'],
        nameToId: nameToId,
      );

      final choices = <Choice>[];
      if (isLast) {
        choices.addAll(_parseChoices(row['choices'], beatId: beatId, sceneIndex: i));
        if (choices.isEmpty) {
          choices.add(
            const Choice(
              id: 'ch_end',
              text: '结束',
              target: Transition(type: TransitionType.end),
            ),
          );
        }
      }

      nodes.add(
        StoryNode(
          id: nodeId,
          title: title,
          synopsis: _stringOf(row['synopsis'])?.trim(),
          beatIds: <String>[beatId],
          layout: NodeLayout(x: i * 220.0, y: 0),
        ),
      );
      beats.add(
        Beat(
          id: beatId,
          nodeId: nodeId,
          scene: Scene(locationText: _stringOf(row['location'])?.trim()),
          appearances: appearances,
          lines: List<DialogueLine>.unmodifiable(lines),
          choices: choices,
        ),
      );
    }

    for (var i = 0; i < nodes.length - 1; i++) {
      if (beats[i].choices.isNotEmpty) continue;
      edges.add(
        StoryEdge(
          id: 'e_${i + 1}',
          from: nodes[i].id,
          to: nodes[i + 1].id,
          kind: EdgeKind.defaultEdge,
        ),
      );
    }

    return MainStory(
      summary: summary.isEmpty ? nodes.first.title : summary,
      startNodeId: nodes.first.id,
      nodes: nodes,
      edges: edges,
      beats: beats,
    );
  }

  static List<DialogueLine> _parseLines(
    Object? linesRaw, {
    required int sceneIndex,
    required Map<String, String> nameToId,
  }) {
    final lines = <DialogueLine>[];
    if (linesRaw is! List) return lines;
    for (var li = 0; li < linesRaw.length; li++) {
      final lineItem = linesRaw[li];
      if (lineItem is! Map) continue;
      final lineMap = Map<String, dynamic>.from(lineItem);
      final text = _stringOf(lineMap['text'])?.trim() ?? '';
      if (text.isEmpty) continue;
      final speakerName = _stringOf(lineMap['speaker'])?.trim();
      final isNarration = speakerName == null ||
          speakerName.isEmpty ||
          speakerName == '旁白' ||
          speakerName.toLowerCase() == 'narrator';
      lines.add(
        DialogueLine(
          id: 'l_${sceneIndex + 1}_$li',
          text: text,
          speakerId: isNarration ? null : nameToId[speakerName],
          kind: isNarration ? DialogueKind.narration : DialogueKind.speech,
        ),
      );
    }
    return lines;
  }

  static List<Appearance> _appearancesFor({
    required List<DialogueLine> lines,
    required Object? speakersHint,
    required Map<String, String> nameToId,
  }) {
    final appearanceIds = <String>{};
    for (final line in lines) {
      final sid = line.speakerId;
      if (sid != null) appearanceIds.add(sid);
    }
    if (speakersHint is List) {
      for (final name in speakersHint) {
        if (name is! String) continue;
        final id = nameToId[name.trim()];
        if (id != null) appearanceIds.add(id);
      }
    }
    final ids = appearanceIds.toList(growable: false);
    return [
      for (var i = 0; i < ids.length; i++)
        Appearance(
          characterId: ids[i],
          slot: ids.length == 1
              ? AppearanceSlot.center
              : (i == 0 ? AppearanceSlot.left : AppearanceSlot.right),
        ),
    ];
  }

  static List<Choice> _parseChoices(
    Object? choicesRaw, {
    required String beatId,
    required int sceneIndex,
  }) {
    final choices = <Choice>[];
    if (choicesRaw is! List) return choices;
    for (var ci = 0; ci < choicesRaw.length; ci++) {
      final choiceItem = choicesRaw[ci];
      if (choiceItem is! Map) continue;
      final choiceMap = Map<String, dynamic>.from(choiceItem);
      final text = _stringOf(choiceMap['text'])?.trim() ?? '';
      if (text.isEmpty) continue;
      final end = choiceMap['end'] == true;
      final stay = choiceMap['stay'] == true;
      final Transition target;
      if (stay && !end) {
        target = Transition.toBeat(beatId);
      } else {
        target = Transition.end();
      }
      choices.add(
        Choice(
          id: 'ch_${sceneIndex + 1}_$ci',
          text: text,
          target: target,
        ),
      );
    }
    return choices;
  }

  static String? _stringOf(Object? value) {
    if (value is String) return value;
    if (value == null) return null;
    return value.toString();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

class StageMapException implements Exception {
  const StageMapException(this.message);

  final String message;

  @override
  String toString() => message;
}
