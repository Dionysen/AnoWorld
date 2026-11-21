import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:anoworld/domain/ai/visual/visual_prompt_actions.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ComfyWorkflowTemplates portrait wires SaveImage to upscale path', () {
    final wf = ComfyWorkflowTemplates.portrait(
      prompt: '1girl, silver_hair',
      upscale: true,
    );
    expect(wf['7']?['inputs']?['steps'], 20);
    expect(wf['9']?['inputs']?['images'], ['92', 0]);
    expect(wf['4']?['inputs']?['text'], contains('silver_hair'));
  });

  test('ComfyWorkflowTemplates scene without upscale saves decode directly', () {
    final wf = ComfyWorkflowTemplates.scene(
      prompt: 'night, city',
      upscale: false,
    );
    expect(wf['9']?['inputs']?['images'], ['8', 0]);
    expect(wf.containsKey('90'), isFalse);
  });

  test('VisualPromptActions.planFromRaw accepts strict JSON', () {
    const raw = '''
{
  "stylePrefix": "masterpiece, anime",
  "negativePrompt": "low quality",
  "characters": [
    {
      "characterId": "c1",
      "name": "A",
      "visualTags": "1girl, black_hair",
      "facing": "left",
      "preferredSlot": "right",
      "portraitPrompt": "masterpiece, 1girl, black_hair, facing left, white background"
    }
  ],
  "scenes": [
    {
      "nodeId": "n1",
      "title": "Gate",
      "presentCharacterIds": ["c1"],
      "scenePrompt": "masterpiece, outdoor, gate, 1girl, black_hair"
    }
  ]
}
''';
    final plan = VisualPromptActions(
      textClient: _FakeTextClient(),
    ).planFromRaw(raw);
    expect(plan.characters, hasLength(1));
    expect(plan.characters.single.facing, SpriteFacing.left);
    expect(plan.characters.single.preferredSlot, AppearanceSlot.right);
    expect(plan.scenes.single.nodeId, 'n1');
    expect(plan.stylePrefix, contains('anime'));
  });

  test('portrait facing tags flip when rewriting prompt', () {
    final right = ComfyWorkflowTemplates.applyFacingToPortraitPrompt(
      'masterpiece, 1girl, facing left, looking left, from side',
      SpriteFacing.right,
    );
    expect(right, contains('facing right'));
    expect(right, isNot(contains('facing left')));
  });
}

class _FakeTextClient implements AiTextClient {
  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) {
    throw UnimplementedError();
  }
}
