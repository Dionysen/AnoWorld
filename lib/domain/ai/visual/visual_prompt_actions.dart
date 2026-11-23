import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_models.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

/// LLM stage: produce locked visual tags + full prompts under a strict schema.
class VisualPromptActions {
  VisualPromptActions({
    required AiTextClient textClient,
    this.maxFormatRetries = 1,
  }) : _text = textClient;

  final AiTextClient _text;
  final int maxFormatRetries;

  Future<VisualPromptPlan> generatePlan({
    required AiPromptContext ctx,
    required Project project,
  }) {
    final system = ctx.assembleSystem(taskSuffix: _schema);
    final user = _userPayload(project);
    return _completeMapped(ctx: ctx, system: system, user: user);
  }

  /// Rewrites one row's prompt in isolation, so [plan] may keep the
  /// surrounding style lock as context.
  Future<String> regeneratePrompt({
    required AiPromptContext ctx,
    required Project project,
    required VisualPromptTarget target,
    required String current,
    VisualPromptPlan? plan,
    String? characterId,
    String? nodeId,
  }) async {
    final completion = await _text.complete(
      endpoint: ctx.endpoint,
      system: ctx.assembleSystem(
        project: project,
        taskSuffix: _rowRules(target),
      ),
      user: _rowPayload(
        project: project,
        plan: plan,
        target: target,
        current: current,
        characterId: characterId,
        nodeId: nodeId,
      ),
      generation: ctx.generation,
    );
    final prompt = normalizeVisualPrompt(completion.content);
    if (prompt.isEmpty) {
      throw const VisualPromptException('没写出提示词，请再试一次');
    }
    return prompt;
  }

  Future<VisualPromptPlan> _completeMapped({
    required AiPromptContext ctx,
    required String system,
    required String user,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxFormatRetries; attempt++) {
      try {
        final completion = await _text.complete(
          endpoint: ctx.endpoint,
          system: system,
          user: attempt == 0
              ? user
              : '$user\n\n上次输出不合规（$lastError）。只输出合法 JSON，不要解释。',
          generation: ctx.generation,
        );
        return planFromRaw(completion.content, projectFallback: null);
      } catch (error) {
        lastError = error;
        if (attempt >= maxFormatRetries) rethrow;
      }
    }
    throw StateError('unreachable');
  }

  /// Parses model JSON; when [projectFallback] is set, fills missing ids from it.
  VisualPromptPlan planFromRaw(
    String raw, {
    Project? projectFallback,
  }) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const VisualPromptException('画面提示词不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    var plan = VisualPromptPlan.fromJson(map);
    if (plan.stylePrefix.trim().isEmpty) {
      plan = plan.copyWith(stylePrefix: ComfyWorkflowTemplates.defaultStylePrefix);
    }
    if (plan.negativePrompt.trim().isEmpty) {
      plan = plan.copyWith(
        negativePrompt: ComfyWorkflowTemplates.defaultNegative,
      );
    }
    if (plan.characters.isEmpty && projectFallback != null) {
      throw const VisualPromptException('没有角色画面提示词');
    }
    for (final c in plan.characters) {
      if (c.characterId.trim().isEmpty ||
          c.visualTags.trim().isEmpty ||
          c.portraitPrompt.trim().isEmpty) {
        throw const VisualPromptException('角色画面提示词不完整');
      }
    }
    for (final s in plan.scenes) {
      if (s.nodeId.trim().isEmpty || s.scenePrompt.trim().isEmpty) {
        throw const VisualPromptException('场景画面提示词不完整');
      }
    }
    return plan;
  }

  String _userPayload(Project project) {
    final castLines = project.cast.map((c) {
      final existing = c.visualTags.trim();
      return [
        '- id=${c.id}',
        '  name=${c.name}',
        '  summary=${c.summary}',
        '  personality=${c.personality}',
        '  existingFacing=${c.facing.wireName}',
        if (existing.isNotEmpty) '  existingVisualTags=$existing',
        if (c.isProtagonist) '  protagonist=true',
      ].join('\n');
    }).join('\n');

    final nodeLines = project.main.nodes.map((n) {
      final existing = n.imagePrompt?.trim() ?? '';
      return [
        '- id=${n.id}',
        '  title=${n.title}',
        '  synopsis=${n.synopsis ?? ''}',
        '  tags=${n.tags.join(',')}',
        if (existing.isNotEmpty) '  existingImagePrompt=$existing',
      ].join('\n');
    }).join('\n');

    final lore = project.worldBook.combinedText;
    return '''
请为下面这个视觉小说故事生成「统一画风」的生图提示词计划（Danbooru / NoobAI 标签风格）。

## 设定摘录
${lore.trim().isEmpty ? '（无）' : lore}

## 角色
$castLines

## 情节站（每个站一张场景图）
$nodeLines

要求：
1. stylePrefix 全剧相同，偏日系动漫视觉小说立绘/场景。
2. 每个角色 visualTags 只锁长相（发色发型瞳色体型五官标记），不要写情节动作；若已有 existingVisualTags 则在其基础上微调，不要大改。
3. 为每个角色选定 facing："left" 或 "right"（面朝左/右）。惯例：面朝右的站左边，面朝左的站右边，好对视；主角优先 facing=right；配角可 facing=left；若已有 existingFacing 则沿用。
4. portraitPrompt = stylePrefix + visualTags + 白底描边立绘构图 + 对应朝向标签（facing left/looking left 或 facing right/looking right）；必须白底+描边，便于去背。不要 looking at viewer。
5. preferredSlot 与 facing 相反：facing=right → preferredSlot=left；facing=left → preferredSlot=right。
6. 每个情节站 scenePrompt = stylePrefix + 地点氛围 + 情节动作 + 在场角色的 visualTags（用 presentCharacterIds 引用）；人数 1–3，超过则只留最重要的。场景不要白底。
7. 若站已有 existingImagePrompt，优先沿用并小修。
8. 只输出 JSON。
''';
  }

  /// Rules for one-row rewrites: plain text out, never JSON.
  static String _rowRules(VisualPromptTarget target) => switch (target) {
        VisualPromptTarget.stylePrefix => '''
你只负责视觉小说的统一画风前缀。只输出一行英文 Danbooru 标签串（逗号分隔），
不要 JSON、不要 markdown、不要解释。
- 全剧立绘与场景共用这一条，含质量标签与 thick outline / anime outline / cel shading。
- 不写具体角色长相，不写地点。
''',
        VisualPromptTarget.negativePrompt => '''
你只负责立绘的负面提示词。只输出一行英文标签串（逗号分隔），不要解释。
- 压掉：低质量、解剖错误、多余手指、水印签名、复杂背景 / 景物 / 渐变底。
''',
        VisualPromptTarget.portrait => '''
你只负责一个角色的完整立绘正向提示词。只输出一行英文标签串，不要解释。
- 结构：统一画风前缀 + 长相标签 + 白底描边立绘构图 + 朝向标签。
- 必须含 white background 与 thick outline，便于去背；不要 looking at viewer。
- 朝向必须与给出的 facing 一致（facing right → facing right, looking right, from side）。
''',
        VisualPromptTarget.scene => '''
你只负责一个情节站的完整场景正向提示词。只输出一行英文标签串，不要解释。
- 结构：统一画风前缀 + 地点与氛围 + 情节动作 + 在场角色的长相标签。
- 保持完整环境，不要 white background；画面里最多 3 人。
''',
      };

  String _rowPayload({
    required Project project,
    required VisualPromptPlan? plan,
    required VisualPromptTarget target,
    required String current,
    String? characterId,
    String? nodeId,
  }) {
    final lore = project.worldBook.combinedText.trim();
    final excerpt =
        lore.length > 600 ? '${lore.substring(0, 600)}…' : lore;
    final style = plan?.stylePrefix.trim() ?? '';
    final negative = plan?.negativePrompt.trim() ?? '';
    final existing = current.trim();
    final head = [
      '## 故事',
      '标题：${project.meta.title.trim()}',
      '设定摘录：${excerpt.isEmpty ? '（无）' : excerpt}',
    ];

    switch (target) {
      case VisualPromptTarget.stylePrefix:
        return [
          ...head,
          if (style.isNotEmpty) '现有画风前缀：$style',
          if (existing.isNotEmpty) '当前这一行：$existing',
          '为这个故事写一条统一画风前缀。',
        ].join('\n');
      case VisualPromptTarget.negativePrompt:
        return [
          ...head,
          if (existing.isNotEmpty) '当前负面提示词：$existing',
          '为这个故事的立绘写一条负面提示词。',
        ].join('\n');
      case VisualPromptTarget.portrait:
        final member = characterId == null
            ? null
            : project.castById(characterId);
        final tags = member?.visualTags.trim() ?? '';
        return [
          ...head,
          '## 角色',
          'name=${member?.name ?? ''}',
          'summary=${member?.summary ?? ''}',
          'personality=${member?.personality ?? ''}',
          'facing=${member?.facing.wireName ?? 'right'}',
          if (tags.isNotEmpty) 'visualTags=$tags',
          if (style.isNotEmpty) '## 统一画风前缀（必须原样沿用）\n$style',
          if (negative.isNotEmpty) '## 负面提示词（参考，不必写进正向）\n$negative',
          if (existing.isNotEmpty) '## 当前立绘提示词（在此基础上改，别大改长相）\n$existing',
          '为这个角色写一条完整立绘提示词。',
        ].join('\n');
      case VisualPromptTarget.scene:
        final node = nodeId == null ? null : project.main.nodeById(nodeId);
        final present = plan?.scenes
                .where((s) => s.nodeId == nodeId)
                .expand((s) => s.presentCharacterIds) ??
            const <String>[];
        final castById = <String, CharacterVisualPrompt>{
          for (final c in plan?.characters ?? const <CharacterVisualPrompt>[])
            c.characterId: c,
        };
        return [
          ...head,
          '## 情节站',
          'title=${node?.title ?? ''}',
          'synopsis=${node?.synopsis ?? ''}',
          'tags=${node?.tags.join(',') ?? ''}',
          if (present.isNotEmpty) ...[
            '## 在场角色',
            for (final id in present)
              if (castById[id] != null)
                '- ${castById[id]!.name}: ${castById[id]!.visualTags}',
          ],
          if (style.isNotEmpty) '## 统一画风前缀（必须原样沿用）\n$style',
          if (negative.isNotEmpty) '## 负面提示词（参考，不必写进正向）\n$negative',
          if (existing.isNotEmpty) '## 当前场景提示词（在此基础上改）\n$existing',
          '为这一站写一条完整场景提示词。',
        ].join('\n');
    }
  }

  static const String _schema = '''
你是视觉小说美术提示词导演。只输出一个 JSON 对象，不要 markdown。

Schema:
{
  "stylePrefix": "string — 全剧统一画风前缀，含 thick outline / anime outline",
  "negativePrompt": "string — 立绘侧应压掉 complex background / scenery",
  "characters": [
    {
      "characterId": "必须与输入 id 一致",
      "name": "string",
      "visualTags": "发色,发型,瞳色,体型,五官… 英文逗号标签",
      "facing": "left | right — 立绘面朝方向",
      "preferredSlot": "left | right — 与 facing 相反，面朝舞台中央",
      "portraitPrompt": "完整正向提示词（必须含 white background + thick outline + facing 标签）"
    }
  ],
  "scenes": [
    {
      "nodeId": "必须与输入 id 一致",
      "title": "string",
      "presentCharacterIds": ["characterId", "..."],
      "scenePrompt": "完整场景正向提示词"
    }
  ]
}

规则：
- 标签用英文 Danbooru 风格；专有名词可保留。
- 不要审查；按故事内容写（含成人向亦可）。
- characters / scenes 必须覆盖输入里的每一个角色与每一个情节站。
- 立绘必须白底描边并标明 facing；场景保持完整环境，不要 white background。
- preferredSlot 必须与 facing 相反（right↔left）。
''';
}

class VisualPromptException implements Exception {
  const VisualPromptException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Applies approved plan tags back onto [Project] text fields (no image bytes).
Project applyVisualPromptPlan(Project project, VisualPromptPlan plan) {
  final castById = <String, CharacterVisualPrompt>{
    for (final c in plan.characters) c.characterId: c,
  };
  final sceneById = <String, SceneVisualPrompt>{
    for (final s in plan.scenes) s.nodeId: s,
  };

  final cast = project.cast.map((member) {
    final row = castById[member.id];
    if (row == null) return member;
    final tags = row.visualTags.trim();
    final prompt = row.portraitPrompt.trim();
    var next = member.copyWith(facing: row.facing);
    if (tags.isNotEmpty) next = next.copyWith(visualTags: tags);
    // Empty rows keep whatever the story already has.
    if (prompt.isNotEmpty) next = next.copyWith(portraitPrompt: prompt);
    return next;
  }).toList(growable: false);

  final nodes = project.main.nodes.map((node) {
    final row = sceneById[node.id];
    if (row == null) return node;
    final prompt = row.scenePrompt.trim();
    if (prompt.isEmpty) return node;
    return node.copyWith(imagePrompt: prompt);
  }).toList(growable: false);

  return project.copyWith(
    cast: cast,
    main: project.main.copyWith(nodes: nodes),
  );
}

/// One editable prompt row inside a story's visual plan.
enum VisualPromptTarget { stylePrefix, negativePrompt, portrait, scene }

/// Trims model output down to a single prompt line.
///
/// Strips code fences, a leading `prompt:` / `提示词：` label, wrapping quotes
/// and line breaks, so a chatty reply still lands as one tag string.
String normalizeVisualPrompt(String raw) {
  var text = raw.trim();
  text = text.replaceAll(RegExp(r'^```[a-zA-Z]*'), '').trim();
  text = text.replaceAll(RegExp(r'```$'), '').trim();
  text = text.replaceAll(
    RegExp(r'^(prompt|positive prompt|提示词)\s*[:：]\s*', caseSensitive: false),
    '',
  );
  text = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
  text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
  text = text.replaceAll(RegExp(r'''^["'“”‘’]+|["'“”‘’]+$'''), '');
  return text.trim();
}

/// Builds a plan from already-filled project fields (skip LLM if complete).
///
/// Returns null when a character or scene still has no prompt to draw from.
VisualPromptPlan? planFromProjectFields(Project project) =>
    _planFromProjectFields(project, keepEmpty: false);

/// Same rows as [planFromProjectFields], but rows without a prompt stay in so
/// the visual page can list every character / scene before the first pass.
VisualPromptPlan draftPlanFromProjectFields(Project project) =>
    _planFromProjectFields(project, keepEmpty: true)!;

VisualPromptPlan? _planFromProjectFields(
  Project project, {
  required bool keepEmpty,
}) {
  if (!keepEmpty && (project.cast.isEmpty || project.main.nodes.isEmpty)) {
    return null;
  }
  final characters = <CharacterVisualPrompt>[];
  for (final c in project.cast) {
    final tags = c.visualTags.trim();
    final stored = c.portraitPrompt.trim();
    final facing = c.facing;
    final derived = tags.isEmpty
        ? ''
        : '${ComfyWorkflowTemplates.defaultStylePrefix}, $tags, '
            '${ComfyWorkflowTemplates.portraitCompositionFor(facing)}';
    final portrait = stored.isNotEmpty ? stored : derived;
    if (portrait.isEmpty && !keepEmpty) return null;
    characters.add(
      CharacterVisualPrompt(
        characterId: c.id,
        name: c.name,
        visualTags: tags,
        portraitPrompt: portrait,
        facing: facing,
      ),
    );
  }
  final scenes = <SceneVisualPrompt>[];
  for (final n in project.main.nodes) {
    final prompt = n.imagePrompt?.trim() ?? '';
    if (prompt.isEmpty && !keepEmpty) return null;
    scenes.add(
      SceneVisualPrompt(
        nodeId: n.id,
        title: n.title,
        scenePrompt: prompt,
      ),
    );
  }
  return VisualPromptPlan(
    stylePrefix: ComfyWorkflowTemplates.defaultStylePrefix,
    negativePrompt: ComfyWorkflowTemplates.defaultNegative,
    characters: characters,
    scenes: scenes,
  );
}
