import 'dart:convert';

import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_base_url.dart';
import 'package:http/http.dart' as http;

/// Fetches models via OpenAI `GET /models` or ComfyUI `GET /models/checkpoints`.
class HttpOpenAiModelCatalog implements AiModelCatalog {
  HttpOpenAiModelCatalog({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Kept for callers/tests; delegates to foundation normalization.
  static String normalizeBaseUrl(String raw) => normalizeOpenAiBaseUrl(raw);

  @override
  Future<List<String>> listModels(AiEndpointConfig endpoint) async {
    if (endpoint.imageKind == AiImageProviderKind.comfyui) {
      return _listComfyFolder(
        endpoint,
        folder: 'checkpoints',
        emptyMessage: 'ComfyUI 里还没有 checkpoint。请把模型放到 models/checkpoints',
        badListMessage: 'ComfyUI 返回的 checkpoint 列表无法识别',
      );
    }
    return _listOpenAiModels(endpoint);
  }

  @override
  Future<List<String>> listLoras(AiEndpointConfig endpoint) async {
    if (endpoint.imageKind != AiImageProviderKind.comfyui) {
      return const <String>[];
    }
    return _listComfyFolder(
      endpoint,
      folder: 'loras',
      emptyMessage: 'ComfyUI 里还没有 LoRA。请把文件放到 models/loras',
      badListMessage: 'ComfyUI 返回的 LoRA 列表无法识别',
      allowEmpty: true,
    );
  }

  Future<List<String>> _listComfyFolder(
    AiEndpointConfig endpoint, {
    required String folder,
    required String emptyMessage,
    required String badListMessage,
    bool allowEmpty = false,
  }) async {
    var raw = (endpoint.baseUrl.isEmpty
            ? endpoint.defaultBaseUrl
            : endpoint.baseUrl)
        .trim();
    if (raw.endsWith('/')) raw = raw.substring(0, raw.length - 1);
    if (raw.isEmpty) {
      throw AiModelCatalogException('请先填写服务地址');
    }

    // ComfyUI root is not OpenAI `/v1`; hit `/models/{folder}` directly.
    final uri = Uri.parse('$raw/models/$folder');
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiModelCatalogException(
        '连不上 ComfyUI 或查找 $folder 失败（错误码 ${response.statusCode}）。'
        '请确认本机已启动并监听 $raw',
      );
    }

    final decoded = jsonDecode(response.body);
    final ids = <String>[];
    if (decoded is List) {
      for (final item in decoded) {
        final id = item?.toString().trim() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
    } else {
      throw AiModelCatalogException(badListMessage);
    }
    ids.sort();
    if (ids.isEmpty && !allowEmpty) {
      throw AiModelCatalogException(emptyMessage);
    }
    return ids;
  }

  Future<List<String>> _listOpenAiModels(AiEndpointConfig endpoint) async {
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
