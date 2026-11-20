import 'dart:convert';

import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads / saves every story's assistant conversation in SharedPreferences.
class CreateAssistantDraftStore {
  CreateAssistantDraftStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const prefsKey = 'anoworld.create_assistant.drafts.v2';

  /// Single-conversation format used before transcripts were per story.
  static const legacyPrefsKey = 'anoworld.create_assistant.draft.v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<CreateAssistantDrafts> load() async {
    try {
      final store = await _prefs();
      final raw = store.getString(prefsKey);
      if (raw == null || raw.isEmpty) {
        final migrated = await _migrateLegacy(store);
        if (migrated != null) return migrated;
        return const CreateAssistantDrafts();
      }
      final decoded = jsonDecode(raw);
      return CreateAssistantDrafts.tryParse(decoded) ??
          const CreateAssistantDrafts();
    } catch (error, stack) {
      AppLog.instance.error(
        '读取创作助手对话失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
      return const CreateAssistantDrafts();
    }
  }

  Future<void> save(CreateAssistantDrafts drafts) async {
    try {
      final store = await _prefs();
      if (drafts.isEmpty) {
        await store.remove(prefsKey);
        AppLog.instance.info('创作助手对话已清空', tag: 'create.assistant');
        return;
      }
      await store.setString(prefsKey, jsonEncode(drafts.toJson()));
      AppLog.instance.info(
        '创作助手对话已保存（${drafts.byStory.length} 个故事）',
        tag: 'create.assistant',
      );
    } catch (error, stack) {
      AppLog.instance.error(
        '保存创作助手对话失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Drops one story's conversation, keeping the others.
  Future<void> removeStory(String projectId) async {
    final drafts = await load();
    if (!drafts.byStory.containsKey(projectId) &&
        drafts.lastProjectId != projectId) {
      return;
    }
    await save(drafts.withoutStory(projectId));
    AppLog.instance.info('创作助手对话已删除（$projectId）', tag: 'create.assistant');
  }

  /// Turns the old single-conversation draft into a per-story one.
  Future<CreateAssistantDrafts?> _migrateLegacy(
    SharedPreferences store,
  ) async {
    final raw = store.getString(legacyPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    final draft = CreateAssistantDraft.tryParse(jsonDecode(raw));
    await store.remove(legacyPrefsKey);
    if (draft == null) return null;
    final migrated = CreateAssistantDrafts.fromLegacyDraft(draft);
    await save(migrated);
    AppLog.instance.info('创作助手对话已迁移到按故事保存', tag: 'create.assistant');
    return migrated;
  }
}
