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

  String get fullText {
    final buffer = StringBuffer()
      ..writeln('[$tag] $message');
    if (error != null) {
      buffer.writeln(error.toString());
    }
    if (stackTrace != null) {
      buffer.write(stackTrace.toString());
    }
    return buffer.toString().trimRight();
  }
}