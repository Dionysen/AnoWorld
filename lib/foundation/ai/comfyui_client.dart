import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Minimal ComfyUI HTTP client: `/prompt` → poll `/history` → `/view`.
class ComfyUiClient {
  ComfyUiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _root(String baseUrl) {
    var raw = baseUrl.trim();
    if (raw.endsWith('/')) raw = raw.substring(0, raw.length - 1);
    return Uri.parse(raw);
  }

  Future<void> ping(String baseUrl, {Duration timeout = const Duration(seconds: 8)}) async {
    final uri = _root(baseUrl).replace(path: '/system_stats');
    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ComfyUiException('无法连接生图服务（${res.statusCode}）');
    }
  }

  Future<String> queuePrompt({
    required String baseUrl,
    required Map<String, dynamic> workflow,
    String clientId = 'anoworld',
  }) async {
    final uri = _root(baseUrl).replace(path: '/prompt');
    final body = jsonEncode(<String, dynamic>{
      'prompt': workflow,
      'client_id': clientId,
    });
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: body,
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ComfyUiException('提交生图失败（${res.statusCode}）：${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw ComfyUiException('生图服务返回异常');
    }
    final map = Map<String, dynamic>.from(decoded);
    final errors = map['node_errors'];
    if (errors is Map && errors.isNotEmpty) {
      throw ComfyUiException('工作流节点错误：$errors');
    }
    final id = map['prompt_id']?.toString();
    if (id == null || id.isEmpty) {
      throw ComfyUiException('生图服务未返回任务 id');
    }
    return id;
  }

  Future<Map<String, dynamic>> waitHistory({
    required String baseUrl,
    required String promptId,
    Duration timeout = const Duration(minutes: 5),
    Duration pollInterval = const Duration(milliseconds: 800),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final uri = _root(baseUrl).replace(path: '/history/$promptId');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 30));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded.containsKey(promptId)) {
          final entry = decoded[promptId];
          if (entry is Map) {
            return Map<String, dynamic>.from(entry);
          }
        }
      }
      await Future<void>.delayed(pollInterval);
    }
    throw ComfyUiException('生图超时');
  }

  /// First image listed in history outputs.
  Future<ComfyUiImageRef> firstImageRef(Map<String, dynamic> historyEntry) async {
    final outputs = historyEntry['outputs'];
    if (outputs is! Map) {
      throw ComfyUiException('生图完成但没有输出');
    }
    for (final value in outputs.values) {
      if (value is! Map) continue;
      final images = value['images'];
      if (images is! List || images.isEmpty) continue;
      final first = images.first;
      if (first is! Map) continue;
      final filename = first['filename']?.toString();
      if (filename == null || filename.isEmpty) continue;
      return ComfyUiImageRef(
        filename: filename,
        subfolder: first['subfolder']?.toString() ?? '',
        type: first['type']?.toString() ?? 'output',
      );
    }
    throw ComfyUiException('生图完成但没有图片');
  }

  Future<Uint8List> downloadImage({
    required String baseUrl,
    required ComfyUiImageRef ref,
  }) async {
    final uri = _root(baseUrl).replace(
      path: '/view',
      queryParameters: <String, String>{
        'filename': ref.filename,
        if (ref.subfolder.isNotEmpty) 'subfolder': ref.subfolder,
        'type': ref.type,
      },
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 120));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ComfyUiException('下载图片失败（${res.statusCode}）');
    }
    return res.bodyBytes;
  }

  /// Queue → wait → download first image bytes.
  Future<Uint8List> generatePng({
    required String baseUrl,
    required Map<String, dynamic> workflow,
    String clientId = 'anoworld',
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final id = await queuePrompt(
      baseUrl: baseUrl,
      workflow: workflow,
      clientId: clientId,
    );
    final history = await waitHistory(
      baseUrl: baseUrl,
      promptId: id,
      timeout: timeout,
    );
    final ref = await firstImageRef(history);
    return downloadImage(baseUrl: baseUrl, ref: ref);
  }
}

class ComfyUiImageRef {
  const ComfyUiImageRef({
    required this.filename,
    this.subfolder = '',
    this.type = 'output',
  });

  final String filename;
  final String subfolder;
  final String type;
}

class ComfyUiException implements Exception {
  ComfyUiException(this.message);
  final String message;

  @override
  String toString() => message;
}
