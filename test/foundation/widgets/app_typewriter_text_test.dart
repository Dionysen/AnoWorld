import 'package:anoworld/foundation/widgets/app_typewriter_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(TypewriterHandle handle, String text, {double speed = 10}) {
  return MaterialApp(
    home: Scaffold(
      body: AppTypewriterText(
        text: text,
        style: const TextStyle(fontSize: 16),
        handle: handle,
        charsPerSecond: speed,
      ),
    ),
  );
}

String _shown(WidgetTester tester) {
  final text = tester.widget<Text>(find.byType(Text));
  return text.data ?? '';
}

void main() {
  testWidgets('reveals characters over time', (tester) async {
    final handle = TypewriterHandle();
    await tester.pumpWidget(_host(handle, '甲乙丙丁戊己庚辛', speed: 10));

    expect(_shown(tester), '甲');
    expect(handle.isDone, isFalse);

    await tester.pump(const Duration(milliseconds: 300));
    final partial = _shown(tester);
    expect(partial.length, greaterThan(1));
    expect(partial, isNot('甲乙丙丁戊己庚辛'));

    await tester.pump(const Duration(seconds: 2));
    expect(_shown(tester), '甲乙丙丁戊己庚辛');
    expect(handle.isDone, isTrue);
  });

  testWidgets('complete() shows the rest of the page at once', (tester) async {
    final handle = TypewriterHandle();
    await tester.pumpWidget(_host(handle, '这一页还没写完'));

    expect(handle.isDone, isFalse);
    handle.complete();
    await tester.pump();
    expect(_shown(tester), '这一页还没写完');
    expect(handle.isDone, isTrue);
  });

  testWidgets('zero speed shows text instantly', (tester) async {
    final handle = TypewriterHandle();
    await tester.pumpWidget(
      _host(handle, '瞬间显示', speed: 0),
    );
    expect(_shown(tester), '瞬间显示');
    expect(handle.isDone, isTrue);
  });

  testWidgets('new text restarts the reveal', (tester) async {
    final handle = TypewriterHandle();
    await tester.pumpWidget(_host(handle, '第一句'));
    await tester.pump(const Duration(seconds: 2));
    expect(handle.isDone, isTrue);

    await tester.pumpWidget(_host(handle, '换了一句更长的对白'));
    expect(_shown(tester), '换');
    expect(handle.isDone, isFalse);
  });
}
