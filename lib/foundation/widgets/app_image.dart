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
    final ImageProvider? base = data != null
        ? MemoryImage(data)
        : (path == null || path!.isEmpty ? null : FileImage(File(path!)));
    if (base == null) return null;
    return ResizeImage.resizeIfNeeded(cacheWidth, null, base);
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
