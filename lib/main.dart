import 'package:anoworld/app.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installImmersiveSystemUi();
  runApp(const App());
}
