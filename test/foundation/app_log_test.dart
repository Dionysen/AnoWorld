import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/logging/app_log_level.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ring buffer caps at maxBufferedEntries', () {
    if (!kDebugMode) return;

    AppLog.instance.clear();
    final startLen = AppLog.instance.length;

    for (var i = 0; i < AppLog.maxBufferedEntries + 50; i++) {
      AppLog.instance.info('line $i', tag: 'test');
    }

    expect(AppLog.instance.length, AppLog.maxBufferedEntries);
    expect(
      AppLog.instance.entryAtNewestFirst(0)?.message,
      contains('${AppLog.maxBufferedEntries + 49}'),
    );

    AppLog.instance.clear();
    expect(AppLog.instance.length, 0);
  });

  test('error entries retain error payload', () {
    if (!kDebugMode) return;

    AppLog.instance.clear();
    AppLog.instance.error(
      'boom',
      tag: 'test',
      error: StateError('bad'),
    );
    final entry = AppLog.instance.entryAtNewestFirst(0);
    expect(entry?.level, AppLogLevel.error);
    expect(entry?.message, 'boom');
    expect(entry?.error, isA<StateError>());
    AppLog.instance.clear();
  });

  test('entries expose HH:mm:ss.SSS timeLabel in fullText', () {
    if (!kDebugMode) return;

    AppLog.instance.clear();
    AppLog.instance.info('hello', tag: 'test');
    final entry = AppLog.instance.entryAtNewestFirst(0);
    expect(entry, isNotNull);
    expect(
      entry!.timeLabel,
      matches(RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}$')),
    );
    expect(entry.fullText, startsWith(entry.timeLabel));
    AppLog.instance.clear();
  });
}