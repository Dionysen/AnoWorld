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

        expect(find.text('AnoWorld'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('page leaves room for the title band and the leading inset', (
    tester,
  ) async {
    const bodyKey = Key('body');
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
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(bodyKey)).dy, 52);
    expect(
      tester.getTopLeft(find.text('Title')).dx,
      78 + (AppTheme.data.appBarTheme.titleSpacing ?? 12),
    );
    final title = tester.widget<Text>(find.text('Title'));
    final theme = Theme.of(tester.element(find.text('Title')));
    expect(
      title.style?.color,
      theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
    );
  });

  testWidgets('page does not overflow in a tiny viewport', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: const ImmersiveScope(
          metrics: ImmersiveMetrics(active: true, titleBarHeight: 36),
          child: AppPage(title: 'Title', body: SizedBox.expand()),
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(120, 24));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('page with back hides chrome when insets leave no room', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: ImmersiveScope(
          metrics: const ImmersiveMetrics(
            active: true,
            titleBarHeight: 36,
            leadingInset: 40,
            trailingInset: 96,
          ),
          child: AppPage(
            title: '设置',
            onBack: () {},
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(160, 200));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
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

final class _MemoryGeometryStore implements WindowGeometryStore {
  WindowGeometry? value;

  @override
  Future<WindowGeometry?> load() async => value;

  @override
  Future<void> save(WindowGeometry geometry) async {
    value = geometry;
  }
}
