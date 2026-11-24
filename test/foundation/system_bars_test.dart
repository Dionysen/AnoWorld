import 'package:anoworld/foundation/frame/system_bars.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final channel = MethodChannel(SystemBars.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;

  setUp(() {
    calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android asks the runner to hide the navigation bar', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(SystemBars.hidesBottomBar, isTrue);

    await SystemBars.hideBottomBar();
    expect(calls, <String>['hideNavigationBar']);
  });

  test('iOS keeps the home indicator and calls nothing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(SystemBars.hidesBottomBar, isFalse);

    await SystemBars.hideBottomBar();
    expect(calls, isEmpty);
  });

  test('a runner without the channel is not an error', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw MissingPluginException();
    });

    await SystemBars.hideBottomBar();
  });
}
