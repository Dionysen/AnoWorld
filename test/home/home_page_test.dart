import 'package:anoworld/app.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

App testApp({MemoryProjectRepository? projects}) {
  return App(
    projects: projects ?? MemoryProjectRepository(),
    saves: MemorySaveRepository(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home shows creation entries and empty library', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('AnoWorld'), findsOneWidget);
    expect(find.text('导入角色卡'), findsOneWidget);
    expect(find.text('粘贴故事'), findsOneWidget);
    expect(find.text('分阶段提示词'), findsOneWidget);
    expect(find.text('还没有作品'), findsOneWidget);
    expect(find.text('试用「雨夜投宿」'), findsOneWidget);
  });

  testWidgets('home lists seeded projects and opens hub', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
      idGenerator: () => 'p_new',
    );

    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();

    expect(find.text('雨夜投宿'), findsOneWidget);
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();

    expect(find.text('开始游玩'), findsOneWidget);
    expect(find.text('少年离家，雨夜投宿。'), findsOneWidget);
  });

  testWidgets('blank create opens project hub', (tester) async {
    final repo = MemoryProjectRepository(idGenerator: () => 'p_blank');
    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建空白作品').first);
    await tester.pumpAndSettle();

    expect(find.text('未命名作品'), findsWidgets);
    expect(find.text('开始游玩'), findsOneWidget);
  });

  testWidgets('settings action opens settings page', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('API 配置稍后接入'), findsOneWidget);
  });

  testWidgets('create entry opens placeholder', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入角色卡'));
    await tester.pumpAndSettle();

    expect(find.text('流程即将接入'), findsOneWidget);
  });

  testWidgets('hub start play opens runtime', (tester) async {
    final sample = const ProjectFactory().createRainNightSample(
      now: DateTime.utc(2026, 1, 1),
    );
    final repo = MemoryProjectRepository(
      seed: {sample.meta.id: sample},
    );
    await tester.pumpWidget(testApp(projects: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('雨夜投宿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始游玩'));
    await tester.pumpAndSettle();

    expect(find.text('视觉小说'), findsOneWidget);
    expect(find.text('该走了。'), findsOneWidget);
  });
}
