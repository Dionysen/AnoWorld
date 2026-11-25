import 'package:anoworld/home/me_tab.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:anoworld/settings/ai_preset_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('settings lists the plot-element library entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testScoped(home: const MeTab()));
    await tester.pumpAndSettle();

    expect(find.text('剧情元素'), findsOneWidget);
    expect(find.text('故事选用的情节素材'), findsOneWidget);

    await tester.tap(find.text('剧情元素'));
    await tester.pumpAndSettle();
    expect(find.byType(PlotElementsLibraryPage), findsOneWidget);
    expect(find.text('剧情元素库'), findsOneWidget);
    expect(find.text('救助流浪猫'), findsOneWidget);
  });

  testWidgets('settings lists the preset entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testScoped(home: const MeTab()));
    await tester.pumpAndSettle();

    expect(find.text('预设'), findsOneWidget);
    expect(find.text('输出风格、采样与提示词'), findsOneWidget);

    await tester.tap(find.text('预设'));
    await tester.pumpAndSettle();
    expect(find.byType(AiPresetPage), findsOneWidget);
    expect(find.text('采样'), findsOneWidget);
  });
}
