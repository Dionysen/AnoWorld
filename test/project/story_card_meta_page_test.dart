import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/project/story_card_meta_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final base = const ProjectFactory().createBlank(
    id: 'p_meta',
    title: '客栈',
    now: DateTime.utc(2026, 1, 1),
  );
  final seeded = base.copyWith(
    meta: base.meta.copyWith(
      card: const StoryCardMeta(
        creator: '阿福',
        version: '1.2',
        creatorNotes: '请勿转载',
        tags: <String>['古风', '客栈'],
      ),
    ),
  );

  testWidgets('shows stored card metadata', (tester) async {
    await tester.pumpWidget(
      testScoped(
        projects: MemoryProjectRepository(seed: {seeded.meta.id: seeded}),
        home: StoryCardMetaPage(projectId: seeded.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片信息'), findsOneWidget);
    expect(find.text('阿福'), findsOneWidget);
    expect(find.text('1.2'), findsOneWidget);
    expect(find.text('古风，客栈'), findsOneWidget);
    expect(find.text('请勿转载'), findsOneWidget);
  });

  testWidgets('saving tags splits on commas', (tester) async {
    final repo = MemoryProjectRepository(seed: {seeded.meta.id: seeded});
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: StoryCardMetaPage(projectId: seeded.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '武侠, 雨夜，室内');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final saved = await repo.open(seeded.meta.id);
    expect(saved.meta.card.tags, <String>['武侠', '雨夜', '室内']);
    expect(saved.meta.card.creator, '阿福');
  });

  testWidgets('editing creator notes keeps other fields', (tester) async {
    final repo = MemoryProjectRepository(seed: {seeded.meta.id: seeded});
    await tester.pumpWidget(
      testScoped(
        projects: repo,
        home: StoryCardMetaPage(projectId: seeded.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('作者注'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '改过的说明');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final saved = await repo.open(seeded.meta.id);
    expect(saved.meta.card.creatorNotes, '改过的说明');
    expect(saved.meta.card.tags, <String>['古风', '客栈']);
  });
}
