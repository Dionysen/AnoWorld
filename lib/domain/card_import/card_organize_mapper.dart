import 'package:anoworld/domain/card_import/card_organize_character_names.dart';
import 'package:anoworld/domain/card_import/card_import_sources.dart';
import 'package:anoworld/domain/card_import/card_organize_models.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/project/entity_id.dart';

class CardOrganizeMapper {
  const CardOrganizeMapper({
    this.sources = const CardImportSources(),
    this.sanitizeAction = const CardSanitizeAction(),
  });

  final CardImportSources sources;
  final CardSanitizeAction sanitizeAction;

  CardOrganizeProposal applyOperations(
    StCardImportDraft draft,
    List<CardOrganizeOperation> operations,
  ) {
    if (operations.isEmpty) {
      throw const CardOrganizeException('没有可应用的整理建议');
    }

    final sourceList = sources.fromDraft(draft);
    var castItems = List<StCardImportItem<CastMember>>.from(draft.castItems);
    var worldItems = List<StCardImportItem<WorldBookEntry>>.from(draft.worldBookItems);
    final changes = <CardOrganizeChangeLine>[];

    for (final op in operations) {
      switch (op.op) {
        case 'noop':
          continue;
        case 'move':
          _applyExtractToCast(
            op: op,
            sources: sourceList,
            castItems: castItems,
            bodyOverride: null,
            changes: changes,
          );
          break;
        case 'extract_to_cast':
          _applyExtractToCast(
            op: op,
            sources: sourceList,
            castItems: castItems,
            bodyOverride: op.body,
            changes: changes,
          );
          break;
        case 'add_cast':
          _applyAddCast(
            op: op,
            sources: sourceList,
            castItems: castItems,
            changes: changes,
          );
          break;
        case 'split_cast':
          _applySplitCast(
            op: op,
            sources: sourceList,
            castItems: castItems,
            changes: changes,
          );
          break;
        case 'update_world':
          _applyUpdateWorld(
            op: op,
            sources: sourceList,
            worldItems: worldItems,
            changes: changes,
          );
          break;
        case 'split_world':
          _applySplit(
            op: op,
            sources: sourceList,
            worldItems: worldItems,
            changes: changes,
          );
          break;
        default:
          continue;
      }
    }

    var next = draft.copyWith(
      castItems: castItems,
      worldBookItems: worldItems,
    );
    next = sanitizeAction.run(next).draft;

    return CardOrganizeProposal(
      draftBefore: draft,
      draftAfter: next,
      changes: changes,
    );
  }

  void _requireSubstring(
    CardOrganizeOperation op,
    List<CardImportSource> sourceList,
    String fragment,
  ) {
    final source = _findSource(op.fromSourceId, sourceList);
    if (source == null) {
      throw CardOrganizeException('找不到来源 ${op.fromSourceId}');
    }
    if (!sources.isSubstringOfSource(op.fromSourceId, fragment, sourceList) &&
        !sources.isSubstringOfSource(source.id, fragment, sourceList)) {
      throw const CardOrganizeException('内容与原文不一致');
    }
  }

  void _applyExtractToCast({
    required CardOrganizeOperation op,
    required List<CardImportSource> sources,
    required List<StCardImportItem<CastMember>> castItems,
    required String? bodyOverride,
    required List<CardOrganizeChangeLine> changes,
  }) {
    final target = op.target;
    final castId = op.castItemId;
    if (target == null || castId == null) return;

    final source = _findSource(op.fromSourceId, sources);
    if (source == null) {
      throw CardOrganizeException('找不到来源 ${op.fromSourceId}');
    }
    final index = castItems.indexWhere((c) => c.id == castId);
    if (index < 0) {
      throw CardOrganizeException('找不到角色 $castId');
    }

    final text = (bodyOverride ?? source.body).trim();
    if (text.isEmpty) return;
    if (bodyOverride != null && bodyOverride.trim().isNotEmpty) {
      _requireSubstring(op, sources, text);
    }

    final item = castItems[index];
    final member = item.value;

    CastMember updated;
    switch (target) {
      case 'cast.summary':
        updated = member.copyWith(summary: _append(member.summary, text));
        changes.add(CardOrganizeChangeLine(
          label: '归到角色简介',
          detail: '${item.title} ← ${source.title}',
        ));
      case 'cast.personality':
        updated = member.copyWith(personality: _append(member.personality, text));
        changes.add(CardOrganizeChangeLine(
          label: '归到性格',
          detail: '${item.title} ← ${source.title}',
        ));
      case 'cast.speechStyle':
        updated = member.copyWith(speechStyle: _append(member.speechStyle, text));
        changes.add(CardOrganizeChangeLine(
          label: '归到说话风格',
          detail: '${item.title} ← ${source.title}',
        ));
      default:
        return;
    }

    castItems[index] = item.copyWith(
      value: updated,
      preview: CardSanitizeAction.previewCast(updated),
    );
  }

  void _applyAddCast({
    required CardOrganizeOperation op,
    required List<CardImportSource> sources,
    required List<StCardImportItem<CastMember>> castItems,
    required List<CardOrganizeChangeLine> changes,
  }) {
    final name = op.castName?.trim() ?? '';
    if (name.isEmpty) return;
    if (CardOrganizeCharacterNames.isFieldLabel(name)) return;
    final bodyLen = (op.body ?? '').trim().length;
    if (!CardOrganizeCharacterNames.isPlausibleNewCharacterName(
      name,
      bodyChars: bodyLen,
    )) {
      return;
    }

    final fields = _sliceFieldsFromOperation(op);
    if (fields.isEmpty) return;
    for (final text in fields.values) {
      _requireSubstring(op, sources, text);
    }

    final id = newEntityId('c');
    var member = CastMember(
      id: id,
      name: name,
      summary: fields['summary'] ?? '',
      personality: fields['personality'] ?? '',
      speechStyle: fields['speechStyle'] ?? '',
    );

    castItems.add(
      StCardImportItem(
        id: id,
        sourceId: 'cast:$id',
        title: name,
        preview: CardSanitizeAction.previewCast(member),
        value: member,
        included: true,
      ),
    );
    changes.add(CardOrganizeChangeLine(
      label: '从设定抽出角色',
      detail: name,
    ));
  }

  void _applySplitCast({
    required CardOrganizeOperation op,
    required List<CardImportSource> sources,
    required List<StCardImportItem<CastMember>> castItems,
    required List<CardOrganizeChangeLine> changes,
  }) {
    if (op.castSlices.isEmpty) return;

    for (final slice in op.castSlices) {
      final castId = slice.castItemId?.trim();
      if (castId != null && castId.isNotEmpty) {
        _mergeSliceIntoCast(
          op: op,
          sources: sources,
          castItems: castItems,
          castId: castId,
          slice: slice,
          changes: changes,
        );
        continue;
      }

      final name = slice.name?.trim() ?? '';
      if (name.isEmpty) continue;
      if (CardOrganizeCharacterNames.isFieldLabel(name)) continue;
      final personalityLen = (slice.personality ?? '').trim().length;
      if (!CardOrganizeCharacterNames.isPlausibleNewCharacterName(
        name,
        bodyChars: personalityLen,
      )) {
        continue;
      }

      for (final text in [
        slice.summary,
        slice.personality,
        slice.speechStyle,
      ]) {
        final t = text?.trim();
        if (t == null || t.isEmpty) continue;
        _requireSubstring(op, sources, t);
      }

      final existing = castItems.indexWhere(
        (c) => c.value.name.trim() == name,
      );
      if (existing >= 0) {
        _mergeSliceIntoCast(
          op: op,
          sources: sources,
          castItems: castItems,
          castId: castItems[existing].id,
          slice: slice,
          changes: changes,
        );
        continue;
      }

      final id = newEntityId('c');
      final member = CastMember(
        id: id,
        name: name,
        summary: slice.summary?.trim() ?? '',
        personality: slice.personality?.trim() ?? '',
        speechStyle: slice.speechStyle?.trim() ?? '',
      );
      castItems.add(
        StCardImportItem(
          id: id,
          sourceId: 'cast:$id',
          title: name,
          preview: CardSanitizeAction.previewCast(member),
          value: member,
          included: true,
        ),
      );
      changes.add(CardOrganizeChangeLine(
        label: '从设定拆出角色',
        detail: name,
      ));
    }
  }

  void _mergeSliceIntoCast({
    required CardOrganizeOperation op,
    required List<CardImportSource> sources,
    required List<StCardImportItem<CastMember>> castItems,
    required String castId,
    required CardOrganizeCastSlice slice,
    required List<CardOrganizeChangeLine> changes,
  }) {
    final index = castItems.indexWhere((c) => c.id == castId);
    if (index < 0) {
      throw CardOrganizeException('找不到角色 $castId');
    }
    var member = castItems[index].value;
    final item = castItems[index];

    if (slice.summary != null && slice.summary!.trim().isNotEmpty) {
      final t = slice.summary!.trim();
      _requireSubstring(op, sources, t);
      member = member.copyWith(summary: _append(member.summary, t));
    }
    if (slice.personality != null && slice.personality!.trim().isNotEmpty) {
      final t = slice.personality!.trim();
      _requireSubstring(op, sources, t);
      member = member.copyWith(personality: _append(member.personality, t));
    }
    if (slice.speechStyle != null && slice.speechStyle!.trim().isNotEmpty) {
      final t = slice.speechStyle!.trim();
      _requireSubstring(op, sources, t);
      member = member.copyWith(speechStyle: _append(member.speechStyle, t));
    }

    castItems[index] = item.copyWith(
      value: member,
      preview: CardSanitizeAction.previewCast(member),
    );
    changes.add(CardOrganizeChangeLine(
      label: '归到已有角色',
      detail: item.title,
    ));
  }

  Map<String, String> _sliceFieldsFromOperation(CardOrganizeOperation op) {
    final body = op.body?.trim() ?? '';
    if (body.isNotEmpty) {
      final target = op.target ?? 'cast.personality';
      return switch (target) {
        'cast.summary' => {'summary': body},
        'cast.speechStyle' => {'speechStyle': body},
        _ => {'personality': body},
      };
    }
    return {};
  }

  void _applyUpdateWorld({
    required CardOrganizeOperation op,
    required List<CardImportSource> sources,
    required List<StCardImportItem<WorldBookEntry>> worldItems,
    required List<CardOrganizeChangeLine> changes,
  }) {
    final body = op.body?.trim() ?? '';
    if (body.isEmpty) return;
    _requireSubstring(op, sources, body);

    final source = _findSource(op.fromSourceId, sources);
    final worldId = source?.worldItemId;
    if (worldId == null) {
      throw const CardOrganizeException('无法定位世界书条目');
    }
    final index = worldItems.indexWhere((w) => w.id == worldId);
    if (index < 0) {
      throw CardOrganizeException('找不到设定 $worldId');
    }

    final item = worldItems[index];
    final updated = item.value.copyWith(body: body);
    worldItems[index] = item.copyWith(
      value: updated,
      preview: CardSanitizeAction.previewText(body),
    );
    changes.add(CardOrganizeChangeLine(
      label: '设定保留世界观',
      detail: item.title,
    ));
  }

  void _applySplit({
    required CardOrganizeOperation op,
    required List<CardImportSource> sources,
    required List<StCardImportItem<WorldBookEntry>> worldItems,
    required List<CardOrganizeChangeLine> changes,
  }) {
    final source = _findSource(op.fromSourceId, sources);
    if (source == null) {
      throw CardOrganizeException('找不到来源 ${op.fromSourceId}');
    }

    for (final entry in op.entries) {
      final body = entry.body.trim();
      if (body.isEmpty) continue;
      if (!this.sources.isSubstringOfSource(op.fromSourceId, body, sources) &&
          !this.sources.isSubstringOfSource(source.id, body, sources)) {
        throw const CardOrganizeException('拆分内容与原文不一致');
      }
      final id = newEntityId('bg');
      worldItems.add(
        StCardImportItem(
          id: id,
          sourceId: 'world:$id',
          title: entry.title.trim().isEmpty ? '设定' : entry.title.trim(),
          preview: CardSanitizeAction.previewText(body),
          value: WorldBookEntry(
            id: id,
            title: entry.title.trim().isEmpty ? '设定' : entry.title.trim(),
            body: body,
            alwaysOn: entry.alwaysOn,
            keys: entry.keys,
          ),
        ),
      );
      changes.add(CardOrganizeChangeLine(
        label: '拆成设定',
        detail: entry.title,
      ));
    }
  }

  CardImportSource? _findSource(String id, List<CardImportSource> sources) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    for (final s in sources) {
      if (s.id.startsWith(id) || id.startsWith(s.id)) return s;
    }
    return null;
  }

  String _append(String existing, String addition) {
    final a = existing.trim();
    final b = addition.trim();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    if (a.contains(b)) return a;
    return '$a\n\n$b';
  }
}