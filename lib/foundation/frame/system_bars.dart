import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mobile system bars the app shell can influence.
///
/// Android: the navigation bar (gesture handle / three buttons) is hidden so it
/// never takes layout space. A bottom-edge swipe reveals it again **without**
/// the dimming scrim used by transient-bars-by-swipe. The status bar stays
/// visible. [hidesBottomBar] is true there, so layouts must not reserve the
/// bottom system inset.
///
/// iOS: the home indicator cannot be hidden by an app, so the bottom safe area
/// stays part of the layout ([hidesBottomBar] is false).
abstract final class SystemBars {
  static const String channelName = 'app/system_bars';
  static const MethodChannel _channel = MethodChannel(channelName);

  /// The bottom system bar is hidden by us, not drawn over the content.
  static bool get hidesBottomBar =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Hides the Android navigation bar; no-op elsewhere or without a runner.
  static Future<void> hideBottomBar() async {
    if (!hidesBottomBar) return;
    try {
      await _channel.invokeMethod<void>('hideNavigationBar');
    } on MissingPluginException {
      // Desktop / tests: nothing to hide.
    } catch (_) {
      // An OEM runner that ignores the call leaves edge-to-edge as it was.
    }
  }
}
