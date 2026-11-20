import 'dart:convert';

import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('keeps one conversation per story', () async {
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDrafts(
        lastProjectId: 'p1',
        byStory: {
          'p1': CreateAssistantDraft(
            projectId: 'p1',
            projectTitle: '雨夜投宿',
            composer: '再冷一点',
            lines: [
              CreateAssistantDraftLine(role: 'user', text: '帮我补设定'),
              CreateAssistantDraftLine(role: 'assistant', text: '补了一段'),
            ],
          ),
          'p2': CreateAssistantDraft(
            projectId: 'p2',
            projectTitle: '山中来信',
            lines: [
              CreateAssistantDraftLine(role: 'user', text: '换个开头'),
            ],
          ),
        },
      ),
    );

    final loaded = await store.load();

    expect(loaded.lastProjectId, 'p1');
    expect(loaded.byStory.keys, containsAll(<String>['p1', 'p2']));
    expect(loaded.byStory['p1']!.projectTitle, '雨夜投宿');
    expect(loaded.byStory['p1']!.composer, '再冷一点');
    expect(loaded.byStory['p1']!.lines, hasLength(2));
    expect(loaded.byStory['p2']!.lines.single.text, '换个开头');
  });

  test('removeStory drops only that story', () async {
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDrafts(
        lastProjectId: 'p1',
        byStory: {
          'p1': CreateAssistantDraft(
            projectId: 'p1',
            lines: [CreateAssistantDraftLine(role: 'user', text: 'hi')],
          ),
          'p2': CreateAssistantDraft(
            projectId: 'p2',
            lines: [CreateAssistantDraftLine(role: 'user', text: 'hello')],
          ),
        },
      ),
    );

    await store.removeStory('p1');
    final loaded = await store.load();

    expect(loaded.byStory.containsKey('p1'), isFalse);
    expect(loaded.byStory.containsKey('p2'), isTrue);
    expect(loaded.lastProjectId, isNull);
  });

  test('input typed before picking a story survives a restart', () async {
    final store = CreateAssistantDraftStore();
    await store.save(const CreateAssistantDrafts(composer: '还没选故事'));

    final loaded = await store.load();

    expect(loaded.composer, '还没选故事');
    expect(loaded.byStory, isEmpty);
  });

  test('empty set clears prefs', () async {
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDrafts(
        byStory: {
          'p1': CreateAssistantDraft(
            projectId: 'p1',
            lines: [CreateAssistantDraftLine(role: 'user', text: 'hi')],
          ),
        },
      ),
    );
    await store.save(const CreateAssistantDrafts());

    final loaded = await store.load();
    expect(loaded.isEmpty, isTrue);
  });

  test('migrates the old single-conversation draft', () async {
    final legacy = const CreateAssistantDraft(
      projectId: 'p1',
      projectTitle: '雨夜投宿',
      composer: '半截输入',
      lines: [
        CreateAssistantDraftLine(role: 'user', text: '帮我补设定'),
        CreateAssistantDraftLine(role: 'assistant', text: '补了一段'),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      CreateAssistantDraftStore.legacyPrefsKey: jsonEncode(legacy.toJson()),
    });
    final store = CreateAssistantDraftStore();

    final loaded = await store.load();

    expect(loaded.lastProjectId, 'p1');
    expect(loaded.byStory['p1']!.lines, hasLength(2));
    expect(loaded.byStory['p1']!.composer, '半截输入');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(CreateAssistantDraftStore.legacyPrefsKey), isNull);
    expect(
      prefs.getString(CreateAssistantDraftStore.prefsKey),
      isNotNull,
    );
  });
}
