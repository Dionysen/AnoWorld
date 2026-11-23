import 'dart:convert';
import 'dart:typed_data';

import 'package:anoworld/domain/card_import/st_character_card_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = StCharacterCardParser();

  test('parses chara_card_v3 json', () {
    final card = parser.parseJsonString('''
{
  "spec": "chara_card_v3",
  "spec_version": "3.0",
  "data": {
    "name": "掌柜",
    "description": "客栈老板",
    "personality": "精明",
    "scenario": "雨夜客栈",
    "first_mes": "哟，投宿？",
    "mes_example": "{{user}}: 有空房吗\\n{{char}}: 有，靠窗那间。",
    "system_prompt": "少系统腔",
    "character_book": {
      "entries": [
        {
          "name": "客栈规矩",
          "content": "雨夜只收现银",
          "keys": ["客栈", "规矩"],
          "constant": false,
          "enabled": true
        },
        {
          "keys": ["废弃"],
          "content": "不该出现",
          "enabled": false
        }
      ]
    }
  }
}
''');
    expect(card.name, '掌柜');
    expect(card.scenario, '雨夜客栈');
    expect(card.bookEntries, hasLength(2));
    expect(card.bookEntries.first.keys, ['客栈', '规矩']);
  });

  test('parses legacy flat json', () {
    final card = parser.parseJsonMap({
      'char_name': '少年',
      'char_persona': '旅人',
      'world_scenario': '边城',
      'char_greeting': '……',
    });
    expect(card.name, '少年');
    expect(card.description, '旅人');
    expect(card.scenario, '边城');
    expect(card.firstMes, '……');
  });

  test('reads character_book entries shipped as a uid map', () {
    final card = parser.parseJsonMap({
      'spec': 'chara_card_v2',
      'data': {
        'name': '店主',
        'character_book': {
          'entries': {
            '0': {
              'keys': '客栈，雨夜',
              'content': '只收现银',
            },
            '1': {
              'key': ['灯笼'],
              'content': '门口挂灯',
            },
          },
        },
      },
    });

    expect(card.bookEntries, hasLength(2));
    expect(card.bookEntries.first.keys, ['客栈', '雨夜']);
    expect(card.bookEntries.last.keys, ['灯笼']);
  });

  test('rewrites legacy placeholders instead of dropping them', () {
    final card = parser.parseJsonMap({
      'spec': 'chara_card_v2',
      'data': {
        'name': '阿福',
        'description': '<char> 是店小二，<USER> 认识他。',
        'mes_example': '<CHARIFNOTGROUP>: 来了\n<BOT>: 楼上请',
        'alternate_greetings': ['<GROUP> 一起坐'],
        'character_book': {
          'entries': [
            {'content': '<CHAR> 怕火'},
          ],
        },
      },
    });

    expect(card.description, '{{char}} 是店小二，{{user}} 认识他。');
    expect(card.mesExample, '{{char}}: 来了\n{{char}}: 楼上请');
    expect(card.alternateGreetings, ['{{group}} 一起坐']);
    expect(card.bookEntries.single.content, '{{char}} 怕火');
  });

  test('parses card author, version, tags and creator notes', () {
    final card = parser.parseJsonMap({
      'spec': 'chara_card_v3',
      'data': {
        'name': '掌柜',
        'creator': '阿福',
        'character_version': '1.2',
        'creator_notes': '<b>请勿转载</b>',
        'tags': ['古风', '客栈'],
      },
    });

    expect(card.creator, '阿福');
    expect(card.characterVersion, '1.2');
    expect(card.creatorNotes, '<b>请勿转载</b>');
    expect(card.tags, ['古风', '客栈']);
  });

  test('reads legacy creatorcomment and tags', () {
    final card = parser.parseJsonMap({
      'name': '旧卡',
      'creatorcomment': '旧作者注',
      'tags': ['旧'],
    });

    expect(card.creatorNotes, '旧作者注');
    expect(card.tags, ['旧']);
  });

  test('parses png chara chunk', () {
    final json = jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': 'PNG角色',
        'description': '从图片来',
        'scenario': '城门',
      },
    });
    final payload = base64Encode(utf8.encode(json));
    final png = _minimalPngWithText('chara', payload);
    final card = parser.parsePngBytes(png);
    expect(card.name, 'PNG角色');
    expect(card.scenario, '城门');
    expect(card.coverImageBytes, same(png));
  });
}

/// Tiny valid-enough PNG (signature + IHDR + tEXt + IEND) for unit tests.
Uint8List _minimalPngWithText(String keyword, String value) {
  // Use embed via hand-built chunks: IHDR 1x1 + tEXt + IEND.
  // Simpler approach: build raw bytes with signature and only tEXt that
  // extractPngTextChunk can walk — IHDR not strictly required by our reader.
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  final keywordBytes = latin1.encode(keyword);
  final valueBytes = latin1.encode(value);
  final data = [...keywordBytes, 0, ...valueBytes];
  final type = ascii.encode('tEXt');
  final length = data.length;
  final iendType = ascii.encode('IEND');
  return Uint8List.fromList([
    ...signature,
    (length >> 24) & 0xFF,
    (length >> 16) & 0xFF,
    (length >> 8) & 0xFF,
    length & 0xFF,
    ...type,
    ...data,
    0,
    0,
    0,
    0, // crc ignored by reader
    0,
    0,
    0,
    0,
    ...iendType,
    0,
    0,
    0,
    0,
  ]);
}
