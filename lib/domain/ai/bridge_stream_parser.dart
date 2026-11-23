import 'dart:convert';

import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';

/// Maps one `lines[]` row of a beat reply; null when it carries no text.
///
/// Shared by the buffered parse and the streaming scanner so a line looks the
/// same whichever path produced it. Speaker resolution is strict: a line is
/// spoken only by a defined cast member; unknown names fall back to narration.
DialogueLine? dialogueLineFromRow(
  Map row, {
  required int index,
  required String beatId,
  required Project project,
  required PlayRole role,
}) {
  var text = '${row['text'] ?? ''}'.trim();
  if (text.isEmpty) return null;
  var speaker = '${row['speaker'] ?? ''}'.trim();

  // Recover the character from a leading「名字：」when speaker is missing or
  // 旁白, but only when that label names a real speaker.
  final labeled = dialogueSpeakerLabel(text);
  if (labeled != null) {
    final labelResolves = resolveDialogueSpeaker(
      speaker: labeled,
      project: project,
      role: role,
    ).recognized;
    if (labelResolves) {
      if (isNarratorSpeaker(speaker)) speaker = labeled;
      text = stripDialogueSpeakerLabel(text);
    }
  }

  final resolved = resolveDialogueSpeaker(
    speaker: speaker,
    project: project,
    role: role,
  );
  return DialogueLine(
    id: '${beatId}_l$index',
    text: text,
    speakerId: resolved.castId,
    kind: resolved.recognized ? DialogueKind.speech : DialogueKind.narration,
  );
}

/// Pulls finished `lines[]` objects out of a partially streamed beat JSON.
///
/// Only whole objects are emitted, so each call returns the lines that just
/// became readable. The raw text is kept so a later chunk can finish an object
/// that was split across the wire.
class BridgeBeatStreamParser {
  BridgeBeatStreamParser({
    required this.project,
    required this.beatId,
    required this.role,
  });

  final Project project;
  final String beatId;
  final PlayRole role;

  final StringBuffer _raw = StringBuffer();
  final List<DialogueLine> _lines = <DialogueLine>[];
  String? _location;
  bool _locationRead = false;

  List<DialogueLine> get lines => List<DialogueLine>.unmodifiable(_lines);

  String? get location => _location;

  /// Feeds one raw chunk; returns the lines that just completed.
  List<DialogueLine> add(String chunk) {
    if (chunk.isEmpty) return const <DialogueLine>[];
    _raw.write(chunk);
    final text = _stripLeadingFence(_raw.toString());
    _readLocation(text);

    final rows = _scanLineRows(text);
    if (rows.length <= _lines.length) return const <DialogueLine>[];
    final added = <DialogueLine>[];
    for (var i = _lines.length; i < rows.length; i++) {
      final line = dialogueLineFromRow(
        rows[i],
        index: i,
        beatId: beatId,
        project: project,
        role: role,
      );
      if (line == null) continue;
      _lines.add(line);
      added.add(line);
    }
    return added;
  }

  void _readLocation(String text) {
    if (_locationRead) return;
    final key = text.indexOf('"location"');
    if (key < 0) return;
    final colon = text.indexOf(':', key);
    if (colon < 0) return;
    final quote = text.indexOf('"', colon + 1);
    if (quote < 0) return;
    final end = _stringEnd(text, quote + 1);
    if (end < 0) return;
    _locationRead = true;
    try {
      final decoded = jsonDecode(text.substring(quote, end + 1));
      if (decoded is String) {
        final trimmed = decoded.trim();
        _location = trimmed.isEmpty ? null : trimmed;
      }
    } catch (_) {
      _locationRead = false;
    }
  }

  /// Index of the closing quote for a string starting at [from], or -1.
  static int _stringEnd(String text, int from) {
    var escape = false;
    for (var i = from; i < text.length; i++) {
      final char = text[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (char == '\\') {
        escape = true;
        continue;
      }
      if (char == '"') return i;
    }
    return -1;
  }

  /// Complete `{...}` rows inside the `lines` array, in order.
  static List<Map> _scanLineRows(String text) {
    final rows = <Map>[];
    final key = text.indexOf('"lines"');
    if (key < 0) return rows;
    final arrayStart = text.indexOf('[', key);
    if (arrayStart < 0) return rows;

    var depth = 0;
    var inString = false;
    var escape = false;
    var objectStart = -1;
    for (var i = arrayStart + 1; i < text.length; i++) {
      final char = text[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (char == '\\') {
          escape = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == '{') {
        if (depth == 0) objectStart = i;
        depth++;
        continue;
      }
      if (char == '}') {
        if (depth == 0) continue;
        depth--;
        if (depth == 0 && objectStart >= 0) {
          final slice = text.substring(objectStart, i + 1);
          try {
            final decoded = jsonDecode(slice);
            if (decoded is Map) rows.add(decoded);
          } catch (_) {
            // Half-written / malformed row: skip it and keep scanning.
          }
          objectStart = -1;
        }
        continue;
      }
      if (char == ']' && depth == 0) break;
    }
    return rows;
  }

  static String _stripLeadingFence(String raw) {
    var text = raw.trimLeft();
    if (!text.startsWith('```')) return text;
    final newline = text.indexOf('\n');
    return newline < 0 ? '' : text.substring(newline + 1);
  }
}
