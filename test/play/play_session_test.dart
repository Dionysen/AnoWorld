import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  final skeleton = const ProjectFactory()
      .createBlank(id: 'p_skel', title: '骨架', now: DateTime.utc(2026, 1, 1))
      .copyWith(
        main: const MainStory(
          summary: '短主线',
          startNodeId: 'n1',
          nodes: [
            StoryNode(
              id: 'n1',
              title: '城门',
              synopsis: '离开',
              beatIds: [],
            ),
            StoryNode(
              id: 'n2',
              title: '客栈',
              synopsis: '投宿',
              beatIds: [],
              tags: ['ending'],
            ),
          ],
          edges: [
            StoryEdge(
              id: 'e1',
              from: 'n1',
              to: 'n2',
              kind: EdgeKind.defaultEdge,
            ),
          ],
          beats: [],
        ),
      );

  Future<void> pumpPlay(
    WidgetTester tester, {
    PlayViewMode mode = PlayViewMode.visualNovel,
  }) async {
    await tester.pumpWidget(
      testScoped(
        home: PlaySessionPage(
          project: sample,
          mode: mode,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('VN play reaches choices then can end', (tester) async {
    await pumpPlay(tester);

    expect(find.text('该走了。'), findsOneWidget);
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('留宿？'), findsOneWidget);
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('住下'), findsOneWidget);
    expect(find.text('再看看'), findsOneWidget);

    await tester.tap(find.text('住下'));
    await tester.pumpAndSettle();
    expect(find.text('本段结束'), findsOneWidget);
  });

  testWidgets('chat mode shows tavern composer shell', (tester) async {
    await pumpPlay(tester, mode: PlayViewMode.chat);

    expect(find.text('输入消息'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.text(sample.meta.title), findsWidgets);
    expect(find.text('该走了。'), findsNothing);
  });

  testWidgets('chat opening autosaves a slot with mode', (tester) async {
    final saves = MemorySaveRepository();
    await tester.pumpWidget(
      testScoped(
        saves: saves,
        home: PlaySessionPage(
          project: sample,
          mode: PlayViewMode.chat,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('保存进度'), findsNothing);
    final slots = await saves.listForProject(sample.meta.id);
    expect(slots, isNotEmpty);
    expect(slots.first.mode, PlayViewMode.chat);
    expect(slots.first.pointer.beatId, 'b1');
  });

  testWidgets('empty skeleton still offers guaranteed next station',
      (tester) async {
    await tester.pumpWidget(
      testScoped(
        home: PlaySessionPage(
          project: skeleton,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('前往：客栈'), findsWidgets);
    await tester.tap(find.text('前往：客栈').first);
    await tester.pumpAndSettle();
    expect(find.text('本段结束'), findsOneWidget);
  });
}
