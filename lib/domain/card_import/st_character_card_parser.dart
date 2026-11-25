import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/domain/card_import/st_card_placeholders.dart';
import 'package:anoworld/domain/card_import/st_character_card.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';
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
    // ST may keep humanized create_date on the root while CCv3 dates sit in data.
    final rootCreateDate = _textOf(json['create_date']);
    if (json.containsKey('spec') && json['data'] is Map) {
      return _fromData(
        Map<String, dynamic>.from(json['data'] as Map),
        sourceLabel: sourceLabel,
        rootCreateDate: rootCreateDate,
      );
    }
    if (json['data'] is Map) {
      final data = Map<String, dynamic>.from(json['data'] as Map);
      if (_stringOf(data['name']) == null && _stringOf(json['name']) != null) {
        data['name'] = json['name'];
      }
      return _fromData(
        data,
        sourceLabel: sourceLabel,
        rootCreateDate: rootCreateDate,
      );
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
    final card = parseJsonMap(map, sourceLabel: sourceLabel);
    return card.copyWith(coverImageBytes: bytes);
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
    String? rootCreateDate,
  }) {
    final name = _stringOf(data['name'])?.trim() ?? '';
    if (name.isEmpty) {
      throw StCharacterCardParseException('角色卡缺少名字');
    }
    return StCharacterCard(
      name: name,
      description: _textOf(data['description']) ?? '',
      personality: _textOf(data['personality']) ?? '',
      scenario: _textOf(data['scenario']) ?? '',
      firstMes: _textOf(data['first_mes']) ?? '',
      mesExample: _textOf(data['mes_example']) ?? '',
      systemPrompt: _textOf(data['system_prompt']) ?? '',
      postHistoryInstructions:
          _textOf(data['post_history_instructions']) ?? '',
      creatorNotes: _textOf(data['creator_notes']) ?? '',
      creator: _textOf(data['creator']) ?? '',
      characterVersion: _textOf(data['character_version']) ?? '',
      tags: _textList(data['tags']),
      creationDate: _creationDateOf(data, rootCreateDate: rootCreateDate),
      modificationDate: StoryCardMeta.formatCardDate(data['modification_date']),
      alternateGreetings: _textList(data['alternate_greetings']),
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
      description: _textOf(json['description']) ??
          _textOf(json['char_persona']) ??
          '',
      personality: _textOf(json['personality']) ?? '',
      scenario: _textOf(json['scenario']) ??
          _textOf(json['world_scenario']) ??
          '',
      firstMes: _textOf(json['first_mes']) ??
          _textOf(json['char_greeting']) ??
          '',
      mesExample: _textOf(json['mes_example']) ??
          _textOf(json['example_dialogue']) ??
          '',
      creatorNotes: _textOf(json['creatorcomment']) ??
          _textOf(json['creator_notes']) ??
          '',
      creator: _textOf(json['creator']) ?? '',
      characterVersion: _textOf(json['character_version']) ?? '',
      tags: _textList(json['tags']),
      creationDate: _creationDateOf(json),
      modificationDate: StoryCardMeta.formatCardDate(json['modification_date']),
      sourceLabel: sourceLabel,
    );
  }

  /// Prefer CCv3 `creation_date`, then in-data / root ST `create_date`.
  String _creationDateOf(
    Map<String, dynamic> data, {
    String? rootCreateDate,
  }) {
    final fromV3 = StoryCardMeta.formatCardDate(data['creation_date']);
    if (fromV3.isNotEmpty) return fromV3;
    final fromData = StoryCardMeta.formatCardDate(data['create_date']);
    if (fromData.isNotEmpty) return fromData;
    return StoryCardMeta.formatCardDate(rootCreateDate);
  }

  List<StCharacterBookEntry> _bookEntries(Object? raw) {
    if (raw is! Map) return const [];
    final entriesRaw = raw['entries'];
    // Spec says list; some exports ship the ST lorebook `{uid: entry}` map.
    final rows = switch (entriesRaw) {
      List() => entriesRaw,
      Map() => entriesRaw.values,
      _ => const <Object?>[],
    };
    final out = <StCharacterBookEntry>[];
    for (final item in rows) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final content = _textOf(row['content'])?.trim() ?? '';
      if (content.isEmpty) continue;
      final disabled = _boolOf(row['disable']) ?? false;
      final enabled = !disabled && (_boolOf(row['enabled']) ?? true);
      out.add(
        StCharacterBookEntry(
          name: _textOf(row['name']) ?? '',
          comment: _textOf(row['comment']) ?? '',
          content: content,
          keys: _keyList(row['keys'] ?? row['key']),
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

  /// Card text with SillyTavern legacy placeholders rewritten to macros.
  static String? _textOf(Object? value) {
    final text = _stringOf(value);
    return text == null ? null : normalizeLegacyCardPlaceholders(text);
  }

  static List<String> _textList(Object? value) {
    return _stringList(value)
        .map(normalizeLegacyCardPlaceholders)
        .toList(growable: false);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Keys are usually a list; a few cards ship one comma-separated string.
  static List<String> _keyList(Object? value) {
    if (value is! String) return _stringList(value);
    return value
        .split(RegExp(r'[,，]'))
        .map((s) => s.trim())
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
