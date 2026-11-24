import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Local raster image from a file path or raw bytes.
///
/// Fills its constraints with [fit], caps decode size at the laid-out width,
/// and shows [fallback] while the source is missing or cannot be decoded.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    this.path,
    this.bytes,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallback,
  });

  final String? path;
  final Uint8List? bytes;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget? fallback;

  ImageProvider? _provider(int? cacheWidth) {
    final data = bytes;
    final ImageProvider? base;
    if (data != null) {
      base = MemoryImage(data);
    } else if (path == null || path!.isEmpty) {
      base = null;
    } else {
      final file = File(path!);
      base = stampedFileImage(file);
    }
    if (base == null) return null;
    return ResizeImage.resizeIfNeeded(cacheWidth, null, base);
  }

  /// File mtime in microseconds (0 when unreadable).
  ///
  /// Regenerated pictures are written over the same path, so the plain
  /// `FileImage` key would keep serving the old frame from the image cache.
  /// Microseconds since epoch from [file]'s modification time (0 when unreadable).
  static int fileModifiedMicros(File file) {
    try {
      return file.lastModifiedSync().microsecondsSinceEpoch;
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = fallback ?? const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = width.isFinite && width > 0
            ? (width * dpr).round()
            : null;
        final provider = _provider(cacheWidth);
        if (provider == null) return empty;
        return Image(
          image: provider,
          fit: fit,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => empty,
        );
      },
    );
  }
}

/// [FileImage] whose cache identity also carries the file's mtime.
///
/// Same path, new pixels (a regenerated portrait) must decode again rather than
/// reuse the cached frame the previous file produced.
ImageProvider stampedFileImage(File file, {double scale = 1.0}) {
  return StampedFileImage(file, scale: scale, stamp: AppImage.fileModifiedMicros(file));
}

class StampedFileImage extends FileImage {
  const StampedFileImage(super.file, {super.scale = 1.0, required this.stamp});

  final int stamp;

  @override
  bool operator ==(Object other) =>
      other is StampedFileImage &&
      other.file.path == file.path &&
      other.scale == scale &&
      other.stamp == stamp;

  @override
  int get hashCode => Object.hash(file.path, scale, stamp);
}
