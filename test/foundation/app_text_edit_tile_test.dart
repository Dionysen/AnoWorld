import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('displayValue masks secrets and handles empty', () {
    expect(
      AppTextEditTile.displayValue(
        '',
        obscureText: true,
        emptyLabel: '未填写',
      ),
      '未填写',
    );
    expect(
      AppTextEditTile.displayValue(
        'sk-abcdefgh',
        obscureText: true,
        emptyLabel: '未填写',
      ),
      '••••efgh',
    );
    expect(
      AppTextEditTile.displayValue(
        'https://api.example.com',
        obscureText: false,
        emptyLabel: '未填写',
      ),
      'https://api.example.com',
    );
  });

  testWidgets('tap opens sheet and saves edited value', (tester) async {
    var saved = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppTextEditTile(
            title: '服务地址',
            subtitle: '接口根地址',
            icon: Icons.link_outlined,
            value: 'https://old.example',
            onSubmitted: (v) => saved = v,
          ),
        ),
      ),
    );

    expect(find.text('服务地址'), findsOneWidget);
    expect(find.text('https://old.example'), findsOneWidget);

    await tester.tap(find.text('服务地址'));
    await tester.pumpAndSettle();

    expect(find.text('保存'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'https://new.example');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, 'https://new.example');
  });
}
