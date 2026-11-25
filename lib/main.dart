import 'package:anoworld/app.dart';
import 'package:anoworld/domain/settings/seed_catalog.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorLogging();
  installImmersiveSystemUi();
  await SeedCatalog.load();
  AppLog.instance.info('应用启动', tag: 'lifecycle');
  runApp(const App());
}

void _installGlobalErrorLogging() {
  FlutterError.onError = (details) {
    AppLog.instance.error(
      details.exceptionAsString(),
      tag: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.error(
      '未捕获异常',
      tag: 'zone',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
}
