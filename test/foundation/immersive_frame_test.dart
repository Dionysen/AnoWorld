import 'package:anoworld/app.dart';
import 'package:anoworld/foundation/frame/window_channel.dart';
import 'package:anoworld/foundation/frame/window_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'home renders without window buttons when the channel is absent',
    (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.text('AnoWorld'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );

  testWidgets('windows caption buttons sit on the top-right edge', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WindowChannel.channel, (call) async {
      if (call.method == 'immersiveTitleBar') {
        return true;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(WindowChannel.channel, null);
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
    final close = tester.getRect(find.byIcon(Icons.close));
    expect(close.right, lessThanOrEqualTo(400));
    expect(close.right, greaterThan(400 - WindowControlMetrics.buttonWidth));
  });
}
