import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:flutter/material.dart';

/// Story-flow page route (horizontal slide + create-assistant chrome).
PageRoute<T> storyRoute<T extends Object?>(Widget page) {
  return AppStorySlidePageRoute<T>(builder: (_) => page);
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
