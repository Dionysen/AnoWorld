import 'dart:convert';

import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:http/http.dart' as http;

/// Fetches models via OpenAI-compatible `GET {baseUrl}/models`.
class HttpOpenAiModelCatalog implements AiModelCatalog {
  HttpOpenAiModelCatalog({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  @override
  Future<List<String>> listModels(AiEndpointConfig endpoint) async {
    final base = normalizeBaseUrl(
      endpoint.baseUrl.isEmpty
          ? endpoint.kind.defaultBaseUrl
          : endpoint.baseUrl,
    );
    if (base.isEmpty) {
      throw AiModelCatalogException('请先填写 Base URL');
    }
    if (endpoint.kind.needsApiKey && endpoint.apiKey.trim().isEmpty) {
      throw AiModelCatalogException('请先填写 API Key');
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
        '探测失败（HTTP ${response.statusCode}）',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AiModelCatalogException('模型列表格式无法识别');
    }
    final data = decoded['data'];
    if (data is! List) {
      throw AiModelCatalogException('模型列表为空或格式错误');
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
      throw AiModelCatalogException('未探测到可用模型');
    }
    return ids;
  }
}
