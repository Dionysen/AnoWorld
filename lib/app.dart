import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/home/home_page.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnoWorld',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data,
      builder: (context, child) {
        return ImmersiveFrame(child: child ?? const SizedBox.shrink());
      },
      home: const HomePage(),
    );
  }
}
