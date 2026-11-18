import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_bottom_nav_icon_capsule.dart';
import 'package:anoworld/home/create_assistant_bloom_outline.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';

/// Panel that blooms from the assistant anchor (bottom-right circle → rounded rect).
class CreateAssistantBloomShell extends StatelessWidget {
  const CreateAssistantBloomShell({
    super.key,
    required this.progress,
    required this.child,
    this.onTapAnchor,
  });

  /// Linear 0…1 from the host controller. Curves are applied once here.
  final Animation<double> progress;
  final Widget child;
  final VoidCallback? onTapAnchor;

  static const double _heightFactor = 0.54;
  static const double _neckGapOpen = CreateAssistantBloomOutline.designNeckGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    final media = MediaQuery.sizeOf(context);
    final isDark = theme.brightness == Brightness.dark;
    final anchor = AppBottomNavIconCapsule.side;
    final targetW = math.min(
      AppTheme.sheetMaxWidth,
      media.width - AppTheme.sheetInset * 2,
    );
    final targetH = media.height * _heightFactor;
    final openRadius = tokens.radius;
    final glassFill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.32 : 0.48,
    );
    final borderColor = theme.colorScheme.outline.withValues(
      alpha: isDark ? 0.45 : 0.35,
    );
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.16);

    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final u = Curves.easeInOutCubic.transform(
          progress.value.clamp(0.0, 1.0),
        );
        final panelW = lerpDouble(anchor, targetW, u)!;
        final panelH = lerpDouble(0, targetH, u)!;
        final neckGap = lerpDouble(0, _neckGapOpen, u)!;
        final totalH = panelH + neckGap + anchor;
        final cornerR = lerpDouble(anchor / 2, openRadius, u)!;
        final contentOpacity = _contentOpacity(panelH, targetH);
        final iconT = Curves.easeInOut.transform(
          ((u - 0.32) / 0.28).clamp(0.0, 1.0),
        );
        final iconColor = Color.lerp(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.primary,
          ((u - 0.18) / 0.55).clamp(0.0, 1.0),
        )!;

        final path = CreateAssistantBloomOutline.build(
          CreateAssistantBloomMetrics(
            width: panelW,
            panelHeight: panelH,
            neckGap: neckGap,
            anchor: anchor,
            cornerRadius: cornerR,
          ),
          neckStrength: u,
        );

        return SizedBox(
          width: panelW,
          height: totalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                painter: _BloomShadowPainter(path: path, color: shadowColor),
                child: ClipPath(
                  clipper: _BloomShapeClipper(path),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: AppLayout.bottomNavBlurSigma,
                      sigmaY: AppLayout.bottomNavBlurSigma,
                    ),
                    child: ColoredBox(
                      color: glassFill,
                      child: Stack(
                        children: [
                          if (contentOpacity > 0.01)
                            Positioned(
                              top: 0,
                              left: 0,
                              width: panelW,
                              height: panelH,
                              child: Opacity(
                                opacity: contentOpacity,
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: child,
                                ),
                              ),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            width: anchor,
                            height: anchor,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onTapAnchor,
                                customBorder: const CircleBorder(),
                                child: Center(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Opacity(
                                        opacity: 1 - iconT,
                                        child: Icon(
                                          Icons.auto_awesome_outlined,
                                          size: 22,
                                          color: iconColor,
                                        ),
                                      ),
                                      Opacity(
                                        opacity: iconT,
                                        child: Icon(
                                          Icons.auto_awesome,
                                          size: 22,
                                          color: iconColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BloomBorderPainter(
                      path: path,
                      color: borderColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fades the body in after the column can lay out, and is fully visible
  /// once the panel reaches its open height.
  static double _contentOpacity(double panelH, double targetH) {
    const minH = CreateAssistantPanel.minLayoutHeight;
    if (panelH <= minH || targetH <= minH) return 0;
    final t = ((panelH - minH) / (targetH - minH)).clamp(0.0, 1.0);
    return Curves.easeOut.transform(t);
  }
}

class _BloomShapeClipper extends CustomClipper<Path> {
  _BloomShapeClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _BloomShapeClipper oldClipper) => true;
}

class _BloomBorderPainter extends CustomPainter {
  _BloomBorderPainter({required this.path, required this.color});

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _BloomBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.path != path;
  }
}

class _BloomShadowPainter extends CustomPainter {
  _BloomShadowPainter({required this.path, required this.color});

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(0, 6)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _BloomShadowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.path != path;
  }
}
