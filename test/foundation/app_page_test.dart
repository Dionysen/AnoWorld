import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('title uses the theme and does not need a model', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const AppPage(title: 'Title', body: SizedBox.expand()),
      ),
    );

    final title = tester.widget<Text>(find.text('Title'));
    final context = tester.element(find.text('Title'));
    expect(title.style, Theme.of(context).textTheme.titleLarge);
  });

  testWidgets('bar clears the title band and the leading inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const ImmersiveScope(
          metrics: ImmersiveMetrics(
            active: true,
            titleBarHeight: 52,
            leadingInset: 78,
          ),
          child: AppPage(
            title: 'Title',
            body: SizedBox.expand(key: Key('body')),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.text('Title')).dx, 78);
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 52);
  });
}
