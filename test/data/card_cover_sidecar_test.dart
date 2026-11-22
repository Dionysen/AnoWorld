import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/data/card_import/card_cover_sidecar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('aw_card_sidecar_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('reads same-name PNG beside a JSON card', () async {
    final jsonPath = p.join(dir.path, 'hero.json');
    await File(jsonPath).writeAsString('{}');
    final png = _pngBytes();
    await File(p.join(dir.path, 'hero.png')).writeAsBytes(png);

    expect(await readCardCoverSidecar(jsonPath), png);
  });

  test('returns null without a PNG or with a non-PNG sibling', () async {
    final jsonPath = p.join(dir.path, 'hero.json');
    await File(jsonPath).writeAsString('{}');
    expect(await readCardCoverSidecar(jsonPath), isNull);

    await File(p.join(dir.path, 'hero.png')).writeAsBytes(const [1, 2, 3]);
    expect(await readCardCoverSidecar(jsonPath), isNull);
  });
}

Uint8List _pngBytes() {
  return Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, //
    0, 0, 0, 0, // fake payload; only the signature is checked
  ]);
}
