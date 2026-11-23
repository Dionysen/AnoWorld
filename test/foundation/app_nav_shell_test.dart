import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  AppNavItem(id: 'general', label: '通用', icon: Icons.tune),
  AppNavItem(id: 'appearance', label: '外观', icon: Icons.palette_outlined),
  AppNavItem(id: 'ai', label: 'AI', icon: Icons.auto_awesome),
  AppNavItem(id: 'about', label: '关于', icon: Icons.info_outline),
];

void main() {
  testWidgets('compact shell uses a floating capsule bottom nav', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var selected = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppNavShell(
                destinations: _items,
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                body: const ColoredBox(
                  color: Color(0xFF112233),
                  child: SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);

    expect(find.byType(BackdropFilter), findsOneWidget);
    final blur = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(blur.filter, isNotNull);

    // Floating insets: capsule content stays inside horizontal margins.
    final labelLeft = tester.getTopLeft(find.text('通用')).dx;
    final labelRight = tester.getBottomRight(find.text('关于')).dx;
    expect(labelLeft, greaterThanOrEqualTo(AppLayout.bottomNavHorizontalInset));
    expect(
      labelRight,
      lessThanOrEqualTo(390 - AppLayout.bottomNavHorizontalInset),
    );

    // Floating above the bottom edge (bar height + bottom inset).
    final labelBottom = tester.getBottomLeft(find.text('外观')).dy;
    expect(
      labelBottom,
      lessThanOrEqualTo(720 - AppLayout.bottomNavBottomInset),
    );
    expect(labelBottom, greaterThan(720 - 120));

    // Outside the capsule stays transparent: body fills the shell.
    final bodyBox = tester.getRect(find.byType(ColoredBox).first);
    expect(bodyBox, const Rect.fromLTWH(0, 0, 390, 720));

    await tester.tap(find.text('AI'));
    await tester.pump();
    expect(selected, 2);
  });

  testWidgets('compact capsule nav does not overflow in a narrow viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: AppNavShell(
            destinations: _items,
            selectedIndex: 0,
            onDestinationSelected: _noop,
            body: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('forceCompact keeps bottom capsule on a wide viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const Scaffold(
          body: AppNavShell(
            destinations: _items,
            selectedIndex: 0,
            onDestinationSelected: _noop,
            forceCompact: true,
            body: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
    // Wide auto mode would use a side rail; forceCompact must stay bottom.
    final labelBottom = tester.getBottomLeft(find.text('通用')).dy;
    expect(labelBottom, greaterThan(720 - 120));
  });

  testWidgets('bottomNavExtras share one capsule beside the main bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppNavShell(
            destinations: _items,
            selectedIndex: 0,
            onDestinationSelected: _noop,
            bottomNavExtras: [
              AppBottomNavExtraCapsule(
                icon: Icons.image_outlined,
                selectedIcon: Icons.image,
                label: '场景',
                selected: true,
                onPressed: () {},
              ),
              AppBottomNavExtraCapsule(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: '设置',
                onPressed: () => tapped = true,
              ),
            ],
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(find.text('场景'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

void _noop(int _) {}
