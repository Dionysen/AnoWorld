import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_underline_tab_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Tab { a, b, c }

void main() {
  testWidgets('swipe selects the next tab', (tester) async {
    var tab = _Tab.a;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppUnderlineTabPager<_Tab>(
                value: tab,
                onChanged: (value) => setState(() => tab = value),
                options: const [
                  AppSegmentOption(value: _Tab.a, label: '全部'),
                  AppSegmentOption(value: _Tab.b, label: '分类'),
                  AppSegmentOption(value: _Tab.c, label: '包'),
                ],
                pages: const [
                  Center(child: Text('page-all')),
                  Center(child: Text('page-cat')),
                  Center(child: Text('page-pack')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('page-all'), findsOneWidget);

    await tester.drag(find.text('page-all'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('page-cat'), findsOneWidget);
    expect(tab, _Tab.b);
  });

  testWidgets('tapping a tab animates to that page', (tester) async {
    var tab = _Tab.a;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppUnderlineTabPager<_Tab>(
                value: tab,
                onChanged: (value) => setState(() => tab = value),
                options: const [
                  AppSegmentOption(value: _Tab.a, label: '全部'),
                  AppSegmentOption(value: _Tab.b, label: '分类'),
                  AppSegmentOption(value: _Tab.c, label: '包'),
                ],
                pages: const [
                  Center(child: Text('page-all')),
                  Center(child: Text('page-cat')),
                  Center(child: Text('page-pack')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('包'));
    await tester.pumpAndSettle();

    expect(find.text('page-pack'), findsOneWidget);
    expect(tab, _Tab.c);
  });
}
