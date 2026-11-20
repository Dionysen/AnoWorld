import 'package:anoworld/foundation/logging/app_log_level.dart';

class AppLogEntry {
  const AppLogEntry({
    required this.id,
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final int id;
  final DateTime time;
  final AppLogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  /// Local clock for console / copy / UI: `HH:mm:ss.SSS`.
  String get timeLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.'
        '${three(time.millisecond)}';
  }

  String get fullText {
    final buffer = StringBuffer()
      ..writeln('$timeLabel [${tag}] $message');
    if (error != null) {
      buffer.writeln(error.toString());
    }
    if (stackTrace != null) {
      buffer.write(stackTrace.toString());
    }
    return buffer.toString().trimRight();
  }
}