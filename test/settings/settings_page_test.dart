import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/settings/about_panel.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpSettings(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testScoped(home: const SettingsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('portrait settings uses bottom section nav', (tester) async {
    await pumpSettings(tester, const Size(390, 844));

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('通用'), findsWidgets);
    expect(find.text('外观'), findsWidgets);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('关于'), findsWidgets);
    expect(find.text('通用选项稍后接入'), findsOneWidget);

    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    expect(find.text('文本 AI'), findsOneWidget);
    expect(find.text('生图 AI'), findsOneWidget);
    expect(find.text('供应商'), findsWidgets);

    await tester.tap(find.text('关于').last);
    await tester.pumpAndSettle();
    expect(find.text(AppAbout.versionLabel), findsOneWidget);
    expect(find.text(AppAbout.tagline), findsOneWidget);
  });

  testWidgets('appearance can switch preset and ui prefs', (tester) async {
    await pumpSettings(tester, const Size(390, 844));
    await tester.tap(find.text('外观').last);
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    expect(find.text('字体大小'), findsOneWidget);
    expect(find.text('圆角大小'), findsOneWidget);
    expect(find.text('午夜'), findsOneWidget);

    await tester.tap(find.text('薄雾'));
    await tester.pumpAndSettle();
    expect(find.text('使用中'), findsOneWidget);

    await tester.tap(find.text('无衬线'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNWidgets(2));
    await tester.drag(find.byType(Slider).first, const Offset(40, 0));
    await tester.pumpAndSettle();
  });

  testWidgets('landscape settings uses side rail sections', (tester) async {
    await pumpSettings(
      tester,
      Size(AppLayout.railBreakpoint + 200, 800),
    );

    expect(find.text('通用选项稍后接入'), findsOneWidget);
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    expect(find.text('供应商'), findsWidgets);
    expect(find.text('保存'), findsWidgets);
  });
}
