import 'package:flutter/services.dart';

/// Desktop window operations. Runners that do not implement the channel leave
/// the system title bar in place.
abstract final class WindowChannel {
  static const String name = 'app/window';

  static const MethodChannel channel = MethodChannel(name);

  static Future<bool> immersiveTitleBar() async {
    try {
      final enabled = await channel.invokeMethod<bool>('immersiveTitleBar');
      return enabled == true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<WindowChromeMetrics?> metrics() async {
    try {
      final raw = await channel.invokeMapMethod<String, Object?>('metrics');
      if (raw == null) {
        return null;
      }
      return WindowChromeMetrics(
        centerY: (raw['centerY'] as num?)?.toDouble(),
        leading: (raw['leading'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> startDragging() => _invoke('startDragging');

  static Future<void> toggleMaximize() => _invoke('toggleMaximize');

  static Future<void> minimize() => _invoke('minimize');

  static Future<void> close() => _invoke('close');

  static Future<void> setMinimumSize(Size size) async {
    try {
      await channel.invokeMethod<void>('setMinimumSize', <String, double>{
        'width': size.width,
        'height': size.height,
      });
    } catch (_) {}
  }

  static void setHandler(Future<Object?> Function(MethodCall call)? handler) {
    channel.setMethodCallHandler(handler);
  }

  static Future<void> _invoke(String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } catch (_) {}
  }
}

final class WindowChromeMetrics {
  const WindowChromeMetrics({this.centerY, this.leading});

  final double? centerY;
  final double? leading;
}
