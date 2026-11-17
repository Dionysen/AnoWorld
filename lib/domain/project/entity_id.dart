import 'dart:math';

/// Short stable-enough ids for in-project entities (entries, cast, presets).
String newEntityId(String prefix) {
  final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
  final suffix = _random.nextInt(1 << 20).toRadixString(16).padLeft(5, '0');
  return '${prefix}_$millis$suffix';
}

final _random = Random();
