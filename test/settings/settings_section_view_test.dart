import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/settings/about_panel.dart';
import 'package:anoworld/settings/settings_section_view.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpSection(
    WidgetTester tester,
    SettingsSection section, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      testScoped(home: SettingsSectionView(section: section)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('general section exposes advanced on its own page', (
    tester,
  ) async {
    await pumpSection(tester, SettingsSection.general);

    expect(find.text('通用'), findsOneWidget);
    // Debug builds expose Advanced; release shows the empty caption instead.
    expect(find.text('高级'), findsOneWidget);
    expect(find.text('关于'), findsNothing);
  });

  testWidgets('appearance section can switch preset and ui prefs', (
    tester,
  ) async {
    await pumpSection(tester, SettingsSection.appearance);

    expect(find.text('主题'), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('主题颜色'), findsWidgets);
    expect(find.text('自定义颜色'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);

    await tester.tap(find.text('自定义颜色'));
    await tester.pumpAndSettle();
    expect(find.text('保存为主题'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
    expect(find.text('应用背景'), findsOneWidget);
    // Tap the left inset margin (outside the floating card) to dismiss.
    await tester.tapAt(const Offset(8, 200));
    await tester.pumpAndSettle();
    expect(find.text('保存为主题'), findsNothing);

    expect(find.text('字体'), findsOneWidget);
    expect(find.text('字体大小'), findsOneWidget);
    expect(find.text('圆角大小'), findsOneWidget);

    await tester.tap(find.text('主题颜色').first);
    await tester.pumpAndSettle();
    final cursorDark = find.text('Cursor 深色');
    await tester.scrollUntilVisible(
      cursorDark,
      200,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(cursorDark, findsOneWidget);
    await tester.tap(cursorDark);
    await tester.pumpAndSettle();
    expect(find.text('Cursor 深色'), findsWidgets);

    expect(find.textContaining('系统字体或导入文件'), findsOneWidget);

    await tester.ensureVisible(find.byType(Slider).first);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    await tester.drag(find.byType(Slider).first, const Offset(40, 0));
    await tester.pumpAndSettle();
  });

  testWidgets('ai section lists text and image providers', (tester) async {
    await pumpSection(
      tester,
      SettingsSection.ai,
      size: const Size(800, 800),
    );

    expect(find.text('AI'), findsOneWidget);
    expect(find.text('当前服务商'), findsWidgets);
    expect(find.text('模型'), findsWidgets);
    expect(find.text('查找模型'), findsWidgets);
    expect(find.text('保存'), findsNothing);
  });

  testWidgets('about section shows brand facts', (tester) async {
    await pumpSection(tester, SettingsSection.about);

    expect(
      find.text(AppStringsSetup.fallback.appVersion(AppAbout.version)),
      findsOneWidget,
    );
    expect(find.text(AppStringsSetup.fallback.appTagline), findsOneWidget);
  });
}
