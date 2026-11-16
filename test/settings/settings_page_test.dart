import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      AppScope(
        projects: MemoryProjectRepository(),
        saves: MemorySaveRepository(),
        child: MaterialApp(
          theme: AppTheme.data,
          builder: (context, child) =>
              ImmersiveFrame(child: child ?? const SizedBox.shrink()),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('portrait settings uses bottom section nav', (tester) async {
    await pumpSettings(tester, const Size(390, 844));

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('通用'), findsWidgets);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('关于'), findsWidgets);
    expect(find.text('通用选项稍后接入'), findsOneWidget);

    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    expect(find.text('API 配置稍后接入'), findsOneWidget);

    await tester.tap(find.text('关于').last);
    await tester.pumpAndSettle();
    expect(find.text('版本 0.1.0'), findsOneWidget);
  });

  testWidgets('landscape settings uses side rail sections', (tester) async {
    await pumpSettings(
      tester,
      Size(AppLayout.railBreakpoint + 200, 800),
    );

    expect(find.text('通用选项稍后接入'), findsOneWidget);
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    expect(find.text('API 配置稍后接入'), findsOneWidget);
  });
}
