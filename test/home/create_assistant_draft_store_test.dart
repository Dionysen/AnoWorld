import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('save and load round-trips draft', () async {
    final store = CreateAssistantDraftStore();
    const draft = CreateAssistantDraft(
      projectId: 'p1',
      projectTitle: '雨夜投宿',
      composer: '半截输入',
      lines: [
        CreateAssistantDraftLine(role: 'user', text: '帮我补设定'),
        CreateAssistantDraftLine(role: 'assistant', text: '还在完善'),
      ],
    );

    await store.save(draft);
    final loaded = await store.load();

    expect(loaded.projectId, 'p1');
    expect(loaded.projectTitle, '雨夜投宿');
    expect(loaded.composer, '半截输入');
    expect(loaded.lines, hasLength(2));
    expect(loaded.lines.first.role, 'user');
    expect(loaded.lines.first.text, '帮我补设定');
    expect(loaded.lines.last.role, 'assistant');
  });

  test('empty draft clears prefs', () async {
    final store = CreateAssistantDraftStore();
    await store.save(
      const CreateAssistantDraft(
        projectId: 'p1',
        projectTitle: 'x',
        lines: [CreateAssistantDraftLine(role: 'user', text: 'hi')],
      ),
    );
    await store.save(const CreateAssistantDraft());
    final loaded = await store.load();
    expect(loaded.isEmpty, isTrue);
  });
}
