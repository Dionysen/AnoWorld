import 'package:anoworld/domain/ai/visual/comfy_workflow_templates.dart';
import 'package:anoworld/domain/ai/visual/visual_image_pipeline.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaultPortraitPrompt needs visualTags', () {
    expect(
      VisualImagePipeline.defaultPortraitPrompt(
        const CastMember(id: 'c1', name: 'A'),
      ),
      isEmpty,
    );
    final prompt = VisualImagePipeline.defaultPortraitPrompt(
      const CastMember(
        id: 'c1',
        name: 'A',
        visualTags: '1girl, black_hair',
        facing: SpriteFacing.left,
      ),
    );
    expect(prompt, contains('black_hair'));
    expect(prompt, contains(ComfyWorkflowTemplates.portraitFacingTags(SpriteFacing.left)));
  });

  test('defaultScenePrompt prefers imagePrompt', () {
    const withPrompt = StoryNode(
      id: 'n1',
      title: '城门',
      beatIds: [],
      imagePrompt: 'night, gate, rain',
    );
    expect(
      VisualImagePipeline.defaultScenePrompt(withPrompt),
      'night, gate, rain',
    );
    const fallback = StoryNode(
      id: 'n2',
      title: '客栈',
      synopsis: '投宿',
      beatIds: [],
    );
    final built = VisualImagePipeline.defaultScenePrompt(fallback);
    expect(built, contains('客栈'));
    expect(built, contains('投宿'));
    expect(built, contains('anime scenery'));
  });
}
