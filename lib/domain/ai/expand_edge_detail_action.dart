import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';

/// Expands a short edge title/notes into richer author notes for AI / play.
class ExpandEdgeDetailAction {
  ExpandEdgeDetailAction({required AiTextClient textClient}) : _text = textClient;

  final AiTextClient _text;

  Future<String> expand({
    required AiTextEndpoint endpoint,
    GenerationPreset? generation,
    required String title,
    required String detail,
    String? fromTitle,
    String? fromSynopsis,
    String? toTitle,
    String? toSynopsis,
  }) async {
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw AiTextException('先写一个标题，再让我帮你展开');
    }

    final raw = (await _text.complete(
      endpoint: endpoint,
      generation: generation,
      system: '''你是视觉小说作者的助手。根据用户给出的岔路标题与草稿，写出更具体的走向说明。
只输出纯文本说明，不要标题、不要 markdown、不要 JSON。
写 2～5 句，说清这条路发生什么、氛围与后果，方便之后生成对白。
不要编造与给定信息矛盾的剧情。''',
      user: '''从这一站：${fromTitle ?? '（未命名）'}
本站目标：${fromSynopsis ?? ''}
走向下一站：${toTitle ?? '（未命名）'}
下一站目标：${toSynopsis ?? ''}
岔路标题：$trimmedTitle
已有草稿：${detail.trim().isEmpty ? '（无，请根据标题合理展开）' : detail.trim()}
请写出更详细的走向说明。''',
    ))
        .content;
    final text = raw.trim();
    if (text.isEmpty) {
      throw AiTextException('没有写出内容，请再试一次');
    }
    return text;
  }
}
