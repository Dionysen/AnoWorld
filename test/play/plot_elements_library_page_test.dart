import 'package:anoworld/home/play_modes_tab.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('play modes tab opens plot elements library', (tester) async {
    await tester.pumpWidget(
      testScoped(home: const PlayModesTab()),
    );
    await tester.pumpAndSettle();

    expect(find.text('玩法还在整理'), findsNothing);
    expect(find.text('剧情元素'), findsOneWidget);
    expect(find.text('全局库，给故事勾着用'), findsOneWidget);

    await tester.tap(find.text('剧情元素'));
    await tester.pumpAndSettle();
    expect(find.byType(PlotElementsLibraryPage), findsOneWidget);
    expect(find.text('全局库'), findsOneWidget);
    expect(find.text('救助流浪猫'), findsOneWidget);
  });
}
