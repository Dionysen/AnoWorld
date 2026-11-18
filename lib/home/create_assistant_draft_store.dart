import 'dart:convert';

import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads / saves [CreateAssistantDraft] in SharedPreferences.
class CreateAssistantDraftStore {
  CreateAssistantDraftStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const prefsKey = 'anoworld.create_assistant.draft.v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<CreateAssistantDraft> load() async {
    try {
      final raw = (await _prefs()).getString(prefsKey);
      if (raw == null || raw.isEmpty) {
        return const CreateAssistantDraft();
      }
      final decoded = jsonDecode(raw);
      return CreateAssistantDraft.tryParse(decoded) ??
          const CreateAssistantDraft();
    } catch (error, stack) {
      AppLog.instance.error(
        '读取创作助手草稿失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
      return const CreateAssistantDraft();
    }
  }

  Future<void> save(CreateAssistantDraft draft) async {
    try {
      final store = await _prefs();
      if (draft.isEmpty) {
        await store.remove(prefsKey);
        AppLog.instance.info('创作助手草稿已清空', tag: 'create.assistant');
        return;
      }
      await store.setString(prefsKey, jsonEncode(draft.toJson()));
      AppLog.instance.info(
        '创作助手草稿已保存（${draft.lines.length} 条）',
        tag: 'create.assistant',
      );
    } catch (error, stack) {
      AppLog.instance.error(
        '保存创作助手草稿失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
