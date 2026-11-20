/// Builds a ≥20-station skeleton JSON for full-graph generate tests.
String buildFullGraphJson({int stations = 20}) {
  assert(stations >= 20);
  final parts = <String>[];
  for (var i = 0; i < stations; i++) {
    final exits = <String>[];
    if (i < stations - 2) {
      exits.add('{"to":"站${i + 1}","kind":"default"}');
    }
    if (i == 2) {
      exits.add(
        '{"to":"站${stations - 1}","kind":"branch","label":"另一条世界线"}',
      );
    }
    if (i == stations - 2) {
      exits.add('{"to":"end","kind":"default","label":"收束"}');
    }
    final ending = i == stations - 1 ? ',"ending":true' : '';
    parts.add(
      '{"title":"站$i","synopsis":"目标$i·路线差异$i"$ending,'
      '"exits":[${exits.join(',')}]}',
    );
  }
  return '{"summary":"测试主线","stations":[${parts.join(',')}]}';
}
