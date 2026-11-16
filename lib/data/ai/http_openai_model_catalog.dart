import 'dart:convert';

import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_base_url.dart';
import 'package:http/http.dart' as http;

/// Fetches models via OpenAI-compatible `GET {baseUrl}/models`.
class HttpOpenAiModelCatalog implements AiModelCatalog {
  HttpOpenAiModelCatalog({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Kept for callers/tests; delegates to foundation normalization.
  static String normalizeBaseUrl(String raw) => normalizeOpenAiBaseUrl(raw);

  @override
  Future<List<String>> listModels(AiEndpointConfig endpoint) async {
    final base = normalizeOpenAiBaseUrl(
      endpoint.baseUrl.isEmpty ? endpoint.defaultBaseUrl : endpoint.baseUrl,
    );
    if (base.isEmpty) {
      throw AiModelCatalogException('请先填写服务地址');
    }
    if (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty) {
      throw AiModelCatalogException('请先填写密钥');
    }

    final uri = Uri.parse('$base/models');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (endpoint.apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${endpoint.apiKey.trim()}',
    };

    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiModelCatalogException(
        '查找模型失败（错误码 ${response.statusCode}）',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AiModelCatalogException('返回内容无法识别，请检查服务地址');
    }
    final data = decoded['data'];
    if (data is! List) {
      throw AiModelCatalogException('没有可用模型，或返回格式不对');
    }

    final ids = <String>[];
    for (final item in data) {
      if (item is Map && item['id'] is String) {
        final id = (item['id'] as String).trim();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    ids.sort();
    if (ids.isEmpty) {
      throw AiModelCatalogException('没有找到可用模型');
    }
    return ids;
  }
}
