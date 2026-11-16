import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpPlay(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        projects: MemoryProjectRepository(),
        saves: MemorySaveRepository(),
        child: MaterialApp(
          theme: AppTheme.data,
          builder: (context, child) =>
              ImmersiveFrame(child: child ?? const SizedBox.shrink()),
          home: PlaySessionPage(project: sample, resumeSave: false),
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

  testWidgets('chat mode reveals the same opening line', (tester) async {
    await pumpPlay(tester);
    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();

    expect(find.text('该走了。'), findsOneWidget);
    expect(find.text('少年'), findsWidgets);
  });

  testWidgets('save writes an auto slot', (tester) async {
    final saves = MemorySaveRepository();
    await tester.pumpWidget(
      AppScope(
        projects: MemoryProjectRepository(),
        saves: saves,
        child: MaterialApp(
          theme: AppTheme.data,
          builder: (context, child) =>
              ImmersiveFrame(child: child ?? const SizedBox.shrink()),
          home: PlaySessionPage(project: sample, resumeSave: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存进度'));
    await tester.pumpAndSettle();

    final slot = await saves.load(sample.meta.id);
    expect(slot, isNotNull);
    expect(slot!.pointer.beatId, 'b1');
  });
}
