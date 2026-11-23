import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/frame/window_channel.dart';
import 'package:anoworld/foundation/frame/window_controls.dart';
import 'package:anoworld/foundation/frame/window_geometry.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets(
    'home renders without window buttons when the channel is absent',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(testApp());
        await tester.pumpAndSettle();

        expect(find.text('会话'), findsWidgets);
        expect(find.byIcon(Icons.close), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('software title sits below empty window chrome', (tester) async {
    const bodyKey = Key('body');
    const chrome = 52.0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const ImmersiveScope(
          metrics: ImmersiveMetrics(
            active: true,
            titleBarHeight: chrome,
            leadingInset: 78,
          ),
          child: AppPage(
            title: 'Title',
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      ),
    );
    await tester.pump();

    final titleTop = tester.getTopLeft(find.text('Title')).dy;
    final bodyTop = tester.getTopLeft(find.byKey(bodyKey)).dy;
    expect(titleTop, greaterThanOrEqualTo(chrome));
    expect(bodyTop, chrome + AppTheme.pageTitleBarHeight);
    // Software title ignores window leadingInset — normal page padding.
    expect(tester.getTopLeft(find.text('Title')).dx, AppTheme.pagePadding);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'desktop chrome stays empty; title bar below on any width',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const bodyKey = Key('body');
      const chrome = AppTheme.titleBandHeight;
      try {
        for (final size in const [Size(390, 844), Size(900, 700)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data,
              home: const ImmersiveScope(
                metrics: ImmersiveMetrics(
                  active: true,
                  titleBarHeight: chrome,
                  leadingInset: 78,
                ),
                child: AppPage(
                  title: '设置',
                  onBack: _noop,
                  body: SizedBox.expand(key: bodyKey),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(chrome, 44);
          expect(AppTheme.pageTitleBarHeight, 44);
          final titleTop = tester.getTopLeft(find.text('设置')).dy;
          final bodyTop = tester.getTopLeft(find.byKey(bodyKey)).dy;
          expect(titleTop, greaterThanOrEqualTo(chrome));
          expect(bodyTop, chrome + AppTheme.pageTitleBarHeight);
          expect(find.byIcon(Icons.arrow_back), findsOneWidget);
          expect(
            tester.getCenter(find.byIcon(Icons.arrow_back)).dy,
            closeTo(tester.getCenter(find.text('设置')).dy, 8),
          );
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('backdrop runs behind the empty window chrome', (tester) async {
    const bodyKey = Key('body');
    const backdropKey = Key('backdrop');
    const chrome = 44.0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const ImmersiveScope(
          metrics: ImmersiveMetrics(active: true, titleBarHeight: chrome),
          child: AppPage(
            title: 'Title',
            showTitle: false,
            background: SizedBox.expand(key: backdropKey),
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      ),
    );
    await tester.pump();

    final backdrop = tester.getRect(find.byKey(backdropKey));
    expect(backdrop.top, 0);
    expect(backdrop.height, 844);
    // Chrome still reserves its band, so the body keeps its old position…
    expect(tester.getTopLeft(find.byKey(bodyKey)).dy, chrome);
    // …and the band itself paints nothing over the backdrop.
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .any((box) => box.color == Colors.transparent),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('page does not overflow in a tiny viewport', (tester) async {    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const ImmersiveScope(
          metrics: ImmersiveMetrics(
            active: true,
            titleBarHeight: AppTheme.titleBandHeight,
          ),
          child: AppPage(title: 'Title', body: SizedBox.expand()),
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(120, 24));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('software title hides when the viewport is too narrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: ImmersiveScope(
          metrics: const ImmersiveMetrics(
            active: true,
            titleBarHeight: AppTheme.titleBandHeight,
          ),
          child: AppPage(
            title: '设置',
            onBack: () {},
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(64, 200));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('设置'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'window buttons sit at the top-right when the runner enables them',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(WindowChannel.channel, (call) async {
        if (call.method == 'immersiveTitleBar') {
          return true;
        }
        return null;
      });
      try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data,
          builder: (context, child) => ImmersiveFrame(
            geometryStore: _MemoryGeometryStore(),
            child: child!,
          ),
          home: const AppPage(title: 'Title', body: SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
        final closeRect = tester.getRect(find.byIcon(Icons.close));
        expect(closeRect.right, lessThanOrEqualTo(400));
        expect(
          closeRect.right,
          greaterThan(400 - WindowControlMetrics.buttonWidth),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(WindowChannel.channel, null);
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      }
    },
  );
}

void _noop() {}

final class _MemoryGeometryStore implements WindowGeometryStore {
  WindowGeometry? value;

  @override
  Future<WindowGeometry?> load() async => value;

  @override
  Future<void> save(WindowGeometry geometry) async {
    value = geometry;
  }
}
