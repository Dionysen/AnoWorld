import 'package:anoworld/foundation/widgets/app_detail_entry.dart';
import 'package:anoworld/foundation/widgets/app_detail_section.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('entry expand when body exceeds preview lines', (tester) async {
    var edited = false;
    const body = '第一行。\n第二行。\n第三行。\n第四行要撑开折叠。\n第五行继续。';

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSection(
            title: '世界书',
            icon: Icons.public_outlined,
            initiallyExpanded: true,
            entries: [
              AppDetailEntry(
                title: '世界观',
                tags: const <String>['常驻'],
                body: body,
              ),
            ],
            onEdit: () => edited = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('展开'), findsNothing);
    expect(find.byTooltip('展开'), findsOneWidget);
    expect(find.text('世界观'), findsOneWidget);
    expect(find.text('常驻'), findsOneWidget);
    // Entry hairline + section footer hairline.
    expect(find.byType(AppListHairline), findsNWidgets(2));

    await tester.tap(find.byTooltip('展开'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('收起'), findsOneWidget);
    expect(find.textContaining('第四行'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });

  testWidgets('shows optional subtitle under the title', (tester) async {
    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSection(
            title: '角色',
            icon: Icons.groups_outlined,
            subtitle: '2 个角色，33 token',
            initiallyExpanded: true,
            entries: const [
              AppDetailEntry(title: '少年', body: '离家远行的旅人'),
            ],
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 个角色，33 token'), findsOneWidget);
  });

  testWidgets('entry tags sit on the same line as the title', (tester) async {
    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSection(
            title: '世界书',
            icon: Icons.public_outlined,
            initiallyExpanded: true,
            entries: const [
              AppDetailEntry(
                title: '客栈规矩',
                tags: <String>['常驻'],
                body: '只收现银。',
              ),
            ],
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('客栈规矩'));
    final tag = tester.getRect(find.text('常驻'));
    expect(tag.left, greaterThan(title.right));
    expect(tag.center.dy, moreOrLessEquals(title.center.dy, epsilon: 6));
  });

  testWidgets('header uses AppListTile chrome with edit', (tester) async {
    var edited = false;

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSection(
            title: '世界书',
            icon: Icons.public_outlined,
            subtitle: '83 条设定，51 条常驻，42638 token',
            initiallyExpanded: true,
            entries: const [
              AppDetailEntry(title: '开场素材', body: '小城雨夜。'),
            ],
            onEdit: () => edited = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppListTile), findsWidgets);
    final icon = tester.getRect(find.byIcon(Icons.public_outlined));
    final title = tester.getRect(find.text('世界书'));
    final subtitle = tester.getRect(
      find.text('83 条设定，51 条常驻，42638 token'),
    );
    final blockMiddle = (title.top + subtitle.bottom) / 2;
    expect(icon.center.dy, moreOrLessEquals(blockMiddle, epsilon: 1.5));

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });

  testWidgets('narrow width does not overflow entry actions', (tester) async {
    const body = '第一行。\n第二行。\n第三行。\n第四行。';

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: AppDetailSection(
                title: '世界书',
                icon: Icons.public_outlined,
                subtitle: '12 条设定，3 条常驻，4210 token',
                initiallyExpanded: true,
                entries: const [
                  AppDetailEntry(
                    title: '世界观',
                    tags: <String>['常驻'],
                    body: body,
                  ),
                ],
                onEdit: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('entry copy puts title and body on clipboard', (tester) async {
    const body = '小城雨夜。';
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSection(
            title: '世界书',
            icon: Icons.public_outlined,
            initiallyExpanded: true,
            entries: const [
              AppDetailEntry(
                title: '客栈',
                tags: <String>['常驻'],
                body: body,
              ),
            ],
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('复制'));
    await tester.pumpAndSettle();

    expect(copied, contains('客栈'));
    expect(copied, contains('常驻'));
    expect(copied, contains(body));
    expect(find.textContaining('已复制'), findsOneWidget);
  });

  testWidgets('section caps entries then reveals the rest', (tester) async {
    final entries = [
      for (var i = 1; i <= 10; i++)
        AppDetailEntry(
          title: '条目$i',
          body: '正文$i',
        ),
    ];

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppDetailSection(
              title: '世界书',
              icon: Icons.public_outlined,
              initiallyExpanded: true,
              entries: entries,
              onEdit: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('条目1'), findsOneWidget);
    expect(find.text('条目8'), findsOneWidget);
    expect(find.text('条目9'), findsNothing);
    expect(find.text('条目10'), findsNothing);
    expect(find.text('还有 2 条'), findsOneWidget);

    final more = find.text('还有 2 条');
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(find.text('还有 2 条'), findsNothing);
    expect(find.text('条目9'), findsOneWidget);
    expect(find.text('条目10'), findsOneWidget);
  });

  testWidgets('collapsed long body still copies full text', (tester) async {
    final longBody = List.generate(20, (i) => '第${i + 1}行很长的设定内容。').join('\n');
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSection(
            title: '世界书',
            icon: Icons.public_outlined,
            initiallyExpanded: true,
            entries: [
              AppDetailEntry(
                title: '长设定',
                body: longBody,
              ),
            ],
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('展开'), findsOneWidget);
    expect(find.textContaining('第20行'), findsNothing);

    await tester.tap(find.byTooltip('复制'));
    await tester.pumpAndSettle();
    expect(copied, contains('长设定'));
    expect(copied, contains('第20行很长的设定内容。'));
  });

  testWidgets('section starts collapsed and expands on header tap', (
    tester,
  ) async {
    var edited = false;

    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppDetailSection(
            title: '世界书',
            icon: Icons.public_outlined,
            subtitle: '1 条设定，0 条常驻，12 token',
            entries: const [
              AppDetailEntry(title: '客栈', body: '雨夜投宿。'),
            ],
            onEdit: () => edited = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('世界书'), findsOneWidget);
    expect(find.text('1 条设定，0 条常驻，12 token'), findsOneWidget);
    expect(find.text('客栈'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

    await tester.tap(find.text('世界书'));
    await tester.pumpAndSettle();
    expect(find.text('客栈'), findsOneWidget);
    expect(find.text('雨夜投宿。'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
    expect(find.text('客栈'), findsOneWidget);
  });
}
