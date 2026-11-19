import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/logging/app_log.dart';

/// Turns a short keyword into a ≤300-char plot-element description + example.
class ExpandPlotElementDescriptionAction {
  ExpandPlotElementDescriptionAction({required AiTextClient textClient})
      : _text = textClient;

  final AiTextClient _text;

  Future<String> expand({
    required AiTextEndpoint endpoint,
    GenerationPreset? generation,
    required String keyword,
    String existingDescription = '',
  }) async {
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      throw AiTextException('请先在设置里配好写故事的服务');
    }
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      throw AiTextException('先写个关键词，再生成描述');
    }

    AppLog.instance.info(
      '生成剧情元素描述：关键词 ${trimmed.length} 字',
      tag: 'plot.elements',
    );

    final draft = existingDescription.trim();
    final raw = (await _text.complete(
      endpoint: endpoint,
      generation: generation,
      system: '''你是视觉小说作者的助手。根据用户给出的剧情元素关键词，写出一段简短说明，供 AI 在支线里按需织入。
只输出纯文本，不要标题、不要 markdown、不要 JSON、不要编号列表。
写法：先用一两句说明这个元素是什么、会怎样推动剧情；再补一句以「示例：」开头的具体小场景。
全文不超过 $kPlotElementDescriptionMaxChars 个汉字或字符。
不要编造与关键词无关的世界观。''',
      user: '''关键词：$trimmed
已有草稿：${draft.isEmpty ? '（无，请根据关键词合理撰写）' : draft}
请写出说明与示例。''',
    ))
        .content;

    final text = PlotElementCatalog.clipDescription(raw);
    if (text.isEmpty) {
      AppLog.instance.warning('剧情元素描述为空', tag: 'plot.elements');
      throw AiTextException('没有写出内容，请再试一次');
    }
    AppLog.instance.info(
      '剧情元素描述已生成：${text.length} 字',
      tag: 'plot.elements',
    );
    return text;
  }
}
