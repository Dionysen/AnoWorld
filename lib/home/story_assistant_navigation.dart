import 'package:anoworld/home/create_assistant_host.dart';
import 'package:flutter/material.dart';

PageRouteBuilder<T> storyRoute<T extends Object?>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => CreateAssistantHost(child: page),
    transitionsBuilder: (_, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Future<T?> pushStoryRoute<T extends Object?>(
  BuildContext context,
  Widget page,
) {
  return Navigator.of(context).push<T>(storyRoute<T>(page));
}

Future<T?> pushStoryRouteReplacement<T extends Object?>(
  BuildContext context,
  Widget page,
) {
  return Navigator.of(context).pushReplacement<T, void>(storyRoute<T>(page));
}