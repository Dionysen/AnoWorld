import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Turns near-white / flat studio backgrounds into alpha for VN sprites.
///
/// Strategy: flood-fill from image borders through high-luminance, low-saturation
/// pixels so interior white clothing is kept when not connected to the edge.
/// Works best when the portrait was generated with a plain white/simple background
/// and a dark character outline.
Uint8List makeSpriteTransparentPng(
  Uint8List pngBytes, {
  int whiteThreshold = 232,
  int maxSaturation = 28,
  int feather = 1,
}) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) return pngBytes;

  final image = decoded.convert(numChannels: 4);
  final w = image.width;
  final h = image.height;
  final bg = List<bool>.filled(w * h, false);
  final queue = <int>[];

  bool isBg(int x, int y) {
    final p = image.getPixel(x, y);
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final maxc = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final minc = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final sat = maxc - minc;
    final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
    return lum >= whiteThreshold && sat <= maxSaturation;
  }

  void tryPush(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (bg[i]) return;
    if (!isBg(x, y)) return;
    bg[i] = true;
    queue.add(i);
  }

  for (var x = 0; x < w; x++) {
    tryPush(x, 0);
    tryPush(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    tryPush(0, y);
    tryPush(w - 1, y);
  }

  var qi = 0;
  while (qi < queue.length) {
    final i = queue[qi++];
    final x = i % w;
    final y = i ~/ w;
    tryPush(x - 1, y);
    tryPush(x + 1, y);
    tryPush(x, y - 1);
    tryPush(x, y + 1);
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (!bg[i]) continue;
      final p = image.getPixel(x, y);
      p.a = 0;
    }
  }

  if (feather > 0) {
    for (var pass = 0; pass < feather; pass++) {
      final soft = <(int, int)>[];
      for (var y = 1; y < h - 1; y++) {
        for (var x = 1; x < w - 1; x++) {
          final i = y * w + x;
          if (bg[i]) continue;
          final p = image.getPixel(x, y);
          if (p.a.toInt() == 0) continue;
          var nearBg = false;
          for (final d in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
            final ni = (y + d.$2) * w + (x + d.$1);
            if (bg[ni] || image.getPixel(x + d.$1, y + d.$2).a.toInt() == 0) {
              nearBg = true;
              break;
            }
          }
          if (nearBg && isBg(x, y)) soft.add((x, y));
        }
      }
      for (final (x, y) in soft) {
        final p = image.getPixel(x, y);
        p.a = 0;
        bg[y * w + x] = true;
      }
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}
