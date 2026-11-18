import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('AppListTileStack uses hairlines not vertical gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      testScoped(
        home: Scaffold(
          body: AppListTileStack(
            tiles: const [
              AppListTile(title: '一'),
              AppListTile(title: '二'),
              AppListTile(title: '三'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppListTile), findsNWidgets(3));
    expect(find.byType(AppListHairline), findsNWidgets(2));
  });
}