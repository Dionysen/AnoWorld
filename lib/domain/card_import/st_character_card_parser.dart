import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/domain/card_import/st_character_card.dart';
import 'package:anoworld/foundation/io/png_text_chunks.dart';

class StCharacterCardParseException implements Exception {
  StCharacterCardParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parses SillyTavern character cards (JSON V2/V3 / legacy, PNG `chara`/`ccv3`).
class StCharacterCardParser {
  const StCharacterCardParser();

  StCharacterCard parseJsonString(
    String raw, {
    String sourceLabel = '',
  }) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw StCharacterCardParseException('角色卡不是有效的 JSON');
    }
    if (decoded is! Map) {
      throw StCharacterCardParseException('角色卡 JSON 格式不对');
    }
    return parseJsonMap(
      Map<String, dynamic>.from(decoded),
      sourceLabel: sourceLabel,
    );
  }

  StCharacterCard parseJsonMap(
    Map<String, dynamic> json, {
    String sourceLabel = '',
  }) {
    if (json.containsKey('spec') && json['data'] is Map) {
      return _fromData(
        Map<String, dynamic>.from(json['data'] as Map),
        sourceLabel: sourceLabel,
      );
    }
    if (json['data'] is Map) {
      final data = Map<String, dynamic>.from(json['data'] as Map);
      if (_stringOf(data['name']) == null && _stringOf(json['name']) != null) {
        data['name'] = json['name'];
      }
      return _fromData(data, sourceLabel: sourceLabel);
    }
    return _fromLegacy(json, sourceLabel: sourceLabel);
  }

  StCharacterCard parsePngBytes(
    Uint8List bytes, {
    String sourceLabel = '',
  }) {
    final payload = extractPngTextChunk(bytes, 'ccv3') ??
        extractPngTextChunk(bytes, 'chara');
    if (payload == null) {
      throw StCharacterCardParseException('这张 PNG 里没有角色卡数据');
    }
    final map = _decodeEmbeddedPayload(payload);
    return parseJsonMap(map, sourceLabel: sourceLabel);
  }

  Map<String, dynamic> _decodeEmbeddedPayload(String payload) {
    final trimmed = payload.trim();
    final candidates = <String>[trimmed];
    final dataPrefix = trimmed.indexOf('base64,');
    if (dataPrefix >= 0) {
      candidates.add(trimmed.substring(dataPrefix + 'base64,'.length));
    }

    for (final candidate in candidates.reversed) {
      try {
        final decoded = utf8.decode(base64Decode(_normalizeBase64(candidate)));
        final json = jsonDecode(decoded);
        if (json is Map) return Map<String, dynamic>.from(json);
      } catch (_) {
        // try next
      }
    }

    try {
      final json = jsonDecode(trimmed);
      if (json is Map) return Map<String, dynamic>.from(json);
    } catch (_) {
      // fall through
    }
    throw StCharacterCardParseException('PNG 里的角色卡数据无法解析');
  }

  String _normalizeBase64(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s'), '');
    final pad = (4 - cleaned.length % 4) % 4;
    return cleaned.padRight(cleaned.length + pad, '=');
  }

  StCharacterCard _fromData(
    Map<String, dynamic> data, {
    required String sourceLabel,
  }) {
    final name = _stringOf(data['name'])?.trim() ?? '';
    if (name.isEmpty) {
      throw StCharacterCardParseException('角色卡缺少名字');
    }
    return StCharacterCard(
      name: name,
      description: _stringOf(data['description']) ?? '',
      personality: _stringOf(data['personality']) ?? '',
      scenario: _stringOf(data['scenario']) ?? '',
      firstMes: _stringOf(data['first_mes']) ?? '',
      mesExample: _stringOf(data['mes_example']) ?? '',
      systemPrompt: _stringOf(data['system_prompt']) ?? '',
      postHistoryInstructions:
          _stringOf(data['post_history_instructions']) ?? '',
      creatorNotes: _stringOf(data['creator_notes']) ?? '',
      alternateGreetings: _stringList(data['alternate_greetings']),
      bookEntries: _bookEntries(data['character_book']),
      sourceLabel: sourceLabel,
    );
  }

  StCharacterCard _fromLegacy(
    Map<String, dynamic> json, {
    required String sourceLabel,
  }) {
    final name =
        (_stringOf(json['name']) ?? _stringOf(json['char_name']))?.trim() ??
            '';
    if (name.isEmpty) {
      throw StCharacterCardParseException('角色卡缺少名字');
    }
    return StCharacterCard(
      name: name,
      description: _stringOf(json['description']) ??
          _stringOf(json['char_persona']) ??
          '',
      personality: _stringOf(json['personality']) ?? '',
      scenario: _stringOf(json['scenario']) ??
          _stringOf(json['world_scenario']) ??
          '',
      firstMes: _stringOf(json['first_mes']) ??
          _stringOf(json['char_greeting']) ??
          '',
      mesExample: _stringOf(json['mes_example']) ??
          _stringOf(json['example_dialogue']) ??
          '',
      sourceLabel: sourceLabel,
    );
  }

  List<StCharacterBookEntry> _bookEntries(Object? raw) {
    if (raw is! Map) return const [];
    final entriesRaw = raw['entries'];
    if (entriesRaw is! List) return const [];
    final out = <StCharacterBookEntry>[];
    for (final item in entriesRaw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final content = _stringOf(row['content'])?.trim() ?? '';
      if (content.isEmpty) continue;
      final disabled = _boolOf(row['disable']) ?? false;
      final enabled = !disabled && (_boolOf(row['enabled']) ?? true);
      out.add(
        StCharacterBookEntry(
          name: _stringOf(row['name']) ?? '',
          comment: _stringOf(row['comment']) ?? '',
          content: content,
          keys: _stringList(row['keys'] ?? row['key']),
          constant: _boolOf(row['constant']) ?? false,
          enabled: enabled,
        ),
      );
    }
    return out;
  }

  static String? _stringOf(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  static bool? _boolOf(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }
}
