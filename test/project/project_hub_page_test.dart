import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/foundation/widgets/app_detail_section.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:anoworld/project/story_card_meta_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final base = const ProjectFactory().createBlank(
    id: 'p_hub',
    title: '客栈',
    now: DateTime.utc(2026, 1, 1),
  );

  testWidgets('story hub lists card info from the story', (tester) async {
    final withCard = base.copyWith(
      meta: base.meta.copyWith(
        card: const StoryCardMeta(
          creator: '阿福',
          version: '1.2',
          creatorNotes: '请勿转载',
          tags: <String>['古风', '客栈'],
        ),
      ),
    );
    await tester.pumpWidget(
      testScoped(
        projects: MemoryProjectRepository(seed: {withCard.meta.id: withCard}),
        home: ProjectHubPage(projectId: withCard.meta.id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('卡片信息'), 200);
    await tester.pumpAndSettle();

    expect(find.text('卡片信息'), findsOneWidget);
    expect(find.text('阿福'), findsOneWidget);
    expect(find.text('1.2'), findsOneWidget);
    expect(find.text('古风'), findsOneWidget);
    expect(find.text('请勿转载'), findsOneWidget);
  });

  testWidgets('card info section opens the editor', (tester) async {
    await tester.pumpWidget(
      testScoped(
        projects: MemoryProjectRepository(seed: {base.meta.id: base}),
        home: ProjectHubPage(projectId: base.meta.id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('卡片信息'), 200);
    await tester.pumpAndSettle();

    expect(find.text('作者、版本、标签都空着，点这里补上'), findsOneWidget);

    final cardSection = find.byType(AppDetailSection).last;
    await tester.tap(
      find.descendant(of: cardSection, matching: find.byTooltip('编辑')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StoryCardMetaPage), findsOneWidget);
  });
}
