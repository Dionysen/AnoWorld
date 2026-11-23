import 'package:anoworld/domain/cast_extract/cast_extraction_models.dart';
import 'package:anoworld/domain/models/cast.dart';

const int _maxSummaryChars = 300;
const int _maxPersonalityChars = 200;
const int _maxSpeechStyleChars = 120;
const int _maxVisualTagsChars = 160;
const int _maxAliases = 6;
const int _maxExamples = 6;

/// One preview row: an extracted character plus how it lands in the cast.
class CastMergeCandidate {
  const CastMergeCandidate({
    required this.extracted,
    required this.member,
    this.existing,
  });

  final ExtractedCast extracted;

  /// Final member to write (existing id when [existing] is set).
  final CastMember member;

  /// Non-null when the character already exists and only empty fields fill in.
  final CastMember? existing;

  bool get isNew => existing == null;
}

/// Drops model output that the source text does not actually contain.
///
/// Names / aliases / example lines must appear literally (after normalising
/// spacing and quotes); otherwise they are hallucinations and the field — or
/// the whole character — is discarded.
ExtractedCast? gateExtractedCast(
  ExtractedCast raw,
  String sourceText, {
  String playerName = '玩家',
  String sourceEntry = '',
}) {
  final name = raw.name.trim();
  if (name.isEmpty) return null;
  final normalizedSource = normalizeCastName(sourceText);
  bool containsLiteral(String needle) {
    final value = needle.trim();
    if (value.isEmpty) return false;
    if (sourceText.contains(value)) return true;
    final normalized = normalizeCastName(value);
    return normalized.isNotEmpty && normalizedSource.contains(normalized);
  }

  if (!containsLiteral(name)) return null;

  String clean(String value) {
    var text = value.trim();
    if (text.isEmpty) return '';
    text = text
        .replaceAll('{{char}}', name)
        .replaceAll('{{Char}}', name)
        .replaceAll('{{user}}', playerName)
        .replaceAll('{{User}}', playerName);
    return text;
  }

  final aliases = <String>[];
  for (final alias in raw.aliases) {
    final value = alias.trim();
    if (value.isEmpty || value == name) continue;
    if (!containsLiteral(value)) continue;
    if (!aliases.any((a) => normalizeCastName(a) == normalizeCastName(value))) {
      aliases.add(value);
    }
    if (aliases.length >= _maxAliases) break;
  }

  final examples = <String>[];
  for (final line in raw.exampleLines) {
    final value = line.trim();
    if (value.isEmpty || !containsLiteral(value)) continue;
    if (!examples.contains(value)) examples.add(value);
    if (examples.length >= _maxExamples) break;
  }

  return ExtractedCast(
    name: name,
    aliases: aliases,
    summary: _cap(clean(raw.summary), _maxSummaryChars),
    personality: _cap(clean(raw.personality), _maxPersonalityChars),
    speechStyle: _cap(clean(raw.speechStyle), _maxSpeechStyleChars),
    exampleLines: examples,
    visualTags: _cap(clean(raw.visualTags), _maxVisualTagsChars),
    sourceEntry: raw.sourceEntry.trim().isEmpty
        ? sourceEntry
        : raw.sourceEntry.trim(),
  );
}

/// Merges gated extractions into the existing cast, one candidate per member.
///
/// Matching is by id / normalised name / alias, so re-running extraction only
/// fills blanks and unions aliases instead of duplicating characters.
List<CastMergeCandidate> buildCastMergeCandidates({
  required Iterable<ExtractedCast> extracted,
  required List<CastMember> existing,
  required String Function() newId,
}) {
  final pool = List<CastMember>.of(existing);
  final out = <CastMergeCandidate>[];
  final indexById = <String, int>{};

  for (final row in extracted) {
    final match = _findMember(pool, row);
    final CastMember member;
    final CastMember? previous;
    if (match == null) {
      member = _newMember(row, newId());
      previous = null;
      pool.add(member);
    } else {
      previous = match;
      member = _fillBlanks(match, row);
      pool[pool.indexOf(match)] = member;
    }

    final existingIndex = indexById[member.id];
    if (existingIndex == null) {
      indexById[member.id] = out.length;
      out.add(
        CastMergeCandidate(
          extracted: row,
          member: member,
          existing: previous,
        ),
      );
    } else {
      final prior = out[existingIndex];
      out[existingIndex] = CastMergeCandidate(
        extracted: prior.extracted,
        member: member,
        existing: prior.existing,
      );
    }
  }
  return out;
}

CastMember? _findMember(List<CastMember> pool, ExtractedCast row) {
  final byName = castMemberForSpeaker(pool, row.name);
  if (byName != null) return byName;
  for (final alias in row.aliases) {
    final byAlias = castMemberForSpeaker(pool, alias);
    if (byAlias != null) return byAlias;
  }
  return null;
}

CastMember _newMember(ExtractedCast row, String id) {
  return CastMember(
    id: id,
    name: row.name,
    aliases: List<String>.unmodifiable(row.aliases.take(_maxAliases)),
    summary: row.summary,
    personality: row.personality,
    speechStyle: row.speechStyle,
    exampleLines: List<String>.unmodifiable(row.exampleLines.take(_maxExamples)),
    visualTags: row.visualTags,
  );
}

/// Fills only blanks; never overwrites author-edited fields or art bindings.
CastMember _fillBlanks(CastMember member, ExtractedCast row) {
  String pick(String current, String incoming) =>
      current.trim().isNotEmpty ? current : incoming;

  final aliases = <String>[...member.aliases];
  for (final alias in row.aliases) {
    final value = alias.trim();
    if (value.isEmpty) continue;
    if (normalizeCastName(value) == normalizeCastName(member.name)) continue;
    if (aliases.any((a) => normalizeCastName(a) == normalizeCastName(value))) {
      continue;
    }
    aliases.add(value);
    if (aliases.length >= _maxAliases) break;
  }

  final examples = <String>[...member.exampleLines];
  for (final line in row.exampleLines) {
    if (examples.length >= _maxExamples) break;
    if (!examples.contains(line)) examples.add(line);
  }

  return member.copyWith(
    aliases: List<String>.unmodifiable(aliases),
    summary: pick(member.summary, row.summary),
    personality: pick(member.personality, row.personality),
    speechStyle: pick(member.speechStyle, row.speechStyle),
    exampleLines: List<String>.unmodifiable(examples),
    visualTags: pick(member.visualTags, row.visualTags),
  );
}

String _cap(String text, int max) {
  if (text.length <= max) return text;
  return text.substring(0, max).trimRight();
}
