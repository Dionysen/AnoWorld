import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/data/project/graph_node_thumbnail_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips png bytes', () async {
    final root = await Directory.systemTemp.createTemp('anoworld_thumbs');
    addTearDown(() => root.deleteSync(recursive: true));
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D]);

    await GraphNodeThumbnailFiles.write(root.path, 'n1', bytes);
    final read = await GraphNodeThumbnailFiles.read(root.path, 'n1');
    expect(read, bytes);

    final all = await GraphNodeThumbnailFiles.readAll(root.path);
    expect(all.keys, ['n1']);

    await GraphNodeThumbnailFiles.delete(root.path, 'n1');
    expect(await GraphNodeThumbnailFiles.read(root.path, 'n1'), isNull);
  });
}