import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('noobai workflow loads RLI style lora by default', () {
    final wf = ComfyWorkflowTemplates.portrait(
      prompt: '1girl, silver_hair, white background',
    );
    final lora = wf['30'] as Map<String, dynamic>;
    expect(lora['class_type'], 'LoraLoader');
    final inputs = lora['inputs'] as Map<String, dynamic>;
    expect(inputs['lora_name'], ComfyWorkflowTemplates.defaultLoraName);
    expect(inputs['strength_model'], ComfyWorkflowTemplates.defaultLoraStrength);
    expect(
      (wf['2'] as Map)['inputs']['model'],
      ['30', 0],
    );
    expect(
      (wf['4'] as Map)['inputs']['clip'],
      ['30', 1],
    );
    expect(
      ComfyWorkflowTemplates.defaultStylePrefix,
      contains('very aesthetic'),
    );
  });

  test('lora can be omitted', () {
    final wf = ComfyWorkflowTemplates.noobaiTxt2Img(
      positive: '1girl',
      width: 768,
      height: 768,
      loraName: null,
      upscale: false,
    );
    expect(wf.containsKey('30'), isFalse);
    expect((wf['2'] as Map)['inputs']['model'], ['1', 0]);
  });
}
