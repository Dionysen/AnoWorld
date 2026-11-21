import 'dart:math';

import 'package:anoworld/domain/models/main_story.dart';

/// Builds NoobAI-XL V-pred API workflows for AnoWorld visual stage.
abstract final class ComfyWorkflowTemplates {
  static const String defaultCheckpoint = 'NoobAI-XL-Vpred-v1.0.safetensors';
  static const String defaultUpscaleModel = 'RealESRGAN_x4plus_anime_6B.pth';
  static const String defaultNegative =
      'worst quality, low quality, lowres, bad hands, mutated hands, '
      'extra digits, bad anatomy, signature, username, watermark, '
      'censored, mosaic, text, logo, complex background, scenery, '
      'photo background, gradient background, patterned background, '
      'busy background';

  static const String defaultStylePrefix =
      'masterpiece, best quality, very awa, absurdres, anime style, '
      'detailed face, sharp focus, thick outline, anime outline, cel shading';

  /// Shared portrait framing (white studio BG for edge flood-fill alpha).
  static const String portraitCompositionBase =
      'solo, standing, upper body, '
      'simple background, white background, plain background, '
      'character focus, thick outline, black outline';

  /// Facing tags so the sprite looks toward stage center when placed opposite.
  static String portraitFacingTags(SpriteFacing facing) => switch (facing) {
        SpriteFacing.left => 'facing left, looking left, from side',
        SpriteFacing.right => 'facing right, looking right, from side',
      };

  static String portraitCompositionFor(SpriteFacing facing) =>
      '$portraitCompositionBase, ${portraitFacingTags(facing)}';

  /// Rewrites facing tags in an edited portrait prompt without wiping the rest.
  static String applyFacingToPortraitPrompt(
    String prompt,
    SpriteFacing facing,
  ) {
    var cleaned = prompt
        .replaceAll(
          RegExp(
            r'\bfacing (?:to the )?(?:left|right)\b,?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\blooking (?:to the )?(?:left|right)\b,?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\bfrom side\b,?\s*', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\blooking at viewer\b,?\s*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r',\s*,+'), ',')
        .trim();
    if (cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    if (cleaned.isEmpty) return portraitCompositionFor(facing);
    return '$cleaned, ${portraitFacingTags(facing)}';
  }

  static Map<String, dynamic> noobaiTxt2Img({
    required String positive,
    String negative = defaultNegative,
    required int width,
    required int height,
    int steps = 20,
    double cfg = 4.5,
    int? seed,
    String checkpoint = defaultCheckpoint,
    bool upscale = true,
    String upscaleModel = defaultUpscaleModel,
    String filenamePrefix = 'anoworld',
  }) {
    final resolvedSeed = seed ?? Random().nextInt(1 << 31);
    final workflow = <String, dynamic>{
      '1': {
        'class_type': 'CheckpointLoaderSimple',
        'inputs': {'ckpt_name': checkpoint},
      },
      '2': {
        'class_type': 'ModelSamplingDiscrete',
        'inputs': {
          'model': ['1', 0],
          'sampling': 'v_prediction',
          'zsnr': true,
        },
      },
      '3': {
        'class_type': 'RescaleCFG',
        'inputs': {
          'model': ['2', 0],
          'multiplier': 0.7,
        },
      },
      '4': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'clip': ['1', 1],
          'text': positive,
        },
      },
      '5': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'clip': ['1', 1],
          'text': negative,
        },
      },
      '6': {
        'class_type': 'EmptyLatentImage',
        'inputs': {
          'width': width,
          'height': height,
          'batch_size': 1,
        },
      },
      '7': {
        'class_type': 'KSampler',
        'inputs': {
          'model': ['3', 0],
          'seed': resolvedSeed,
          'steps': steps,
          'cfg': cfg,
          'sampler_name': 'euler',
          'scheduler': 'normal',
          'positive': ['4', 0],
          'negative': ['5', 0],
          'latent_image': ['6', 0],
          'denoise': 1.0,
        },
      },
      '8': {
        'class_type': 'VAEDecode',
        'inputs': {
          'samples': ['7', 0],
          'vae': ['1', 2],
        },
      },
    };

    if (upscale) {
      workflow['90'] = {
        'class_type': 'UpscaleModelLoader',
        'inputs': {'model_name': upscaleModel},
      };
      workflow['91'] = {
        'class_type': 'ImageUpscaleWithModel',
        'inputs': {
          'upscale_model': ['90', 0],
          'image': ['8', 0],
        },
      };
      workflow['92'] = {
        'class_type': 'ImageScaleBy',
        'inputs': {
          'image': ['91', 0],
          'upscale_method': 'lanczos',
          'scale_by': 0.5,
        },
      };
      workflow['9'] = {
        'class_type': 'SaveImage',
        'inputs': {
          'images': ['92', 0],
          'filename_prefix': filenamePrefix,
        },
      };
    } else {
      workflow['9'] = {
        'class_type': 'SaveImage',
        'inputs': {
          'images': ['8', 0],
          'filename_prefix': filenamePrefix,
        },
      };
    }
    return workflow;
  }

  static Map<String, dynamic> portrait({
    required String prompt,
    String negative = defaultNegative,
    bool upscale = true,
    String checkpoint = defaultCheckpoint,
  }) {
    return noobaiTxt2Img(
      positive: prompt,
      negative: negative,
      width: 768,
      height: 1152,
      steps: 20,
      cfg: 4.5,
      upscale: upscale,
      checkpoint: checkpoint,
      filenamePrefix: 'anoworld_avatar',
    );
  }

  static Map<String, dynamic> scene({
    required String prompt,
    String negative = defaultNegative,
    bool upscale = true,
    String checkpoint = defaultCheckpoint,
  }) {
    return noobaiTxt2Img(
      positive: prompt,
      negative: negative,
      width: 1216,
      height: 832,
      steps: 22,
      cfg: 4.5,
      upscale: upscale,
      checkpoint: checkpoint,
      filenamePrefix: 'anoworld_scene',
    );
  }
}
