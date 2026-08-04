import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../models/background_preset.dart';
import '../providers/background_provider.dart';

/// Diffuse background that uses the active preset's circles/image.
class DiffuseBackground extends StatelessWidget {
  final Widget child;

  const DiffuseBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BackgroundProvider>();
    if (!bp.loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => bp.load());
    }
    final active = bp.activePreset;

    return Stack(
      children: [
        // Image background (if set)
        // 公式与 image_edit_screen.dart _imageLayer 完全一致
        // scale = dispW / containerW,  offset = fraction of container
        if (active != null && active.imagePath != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final scale = active.imageScale.clamp(0.3, 4.0);
                final imgW = active.imageOriginalW > 0
                    ? active.imageOriginalW
                    : 1080;
                final imgH = active.imageOriginalH > 0
                    ? active.imageOriginalH
                    : 1920;
                final aspect = (imgW > 0 && imgH > 0) ? imgW / imgH : 1.0;
                final dispW = w * scale;
                final dispH = dispW / aspect;
                return ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: (w - dispW) / 2 + active.imageOffsetX * w,
                        top: (h - dispH) / 2 + active.imageOffsetY * h,
                        width: dispW,
                        height: dispH,
                        child: Image.file(
                          File(active.imagePath!),
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Circles
        if (active != null)
          ...active.circles.map((c) => Positioned(
            left: c.x,
            top: c.y,
            child: Container(
              width: c.width,
              height: c.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(c.radius),
                gradient: RadialGradient(
                  colors: [Color(c.colorValue), Color(c.colorValue).withOpacity(0)],
                ),
              ),
            ),
          )),

        // Fallback: default circles if no preset loaded
        if (bp.loaded && active == null)
          ...[
            Positioned(
              left: 0, top: 0,
              child: _BlurCircle(
                width: AppSpacing.blurCircleLarge,
                height: AppSpacing.blurCircleLarge,
                radius: AppSpacing.blurPinkRadius,
                color: AppColors.blurPinkCenter,
              ),
            ),
            Positioned(
              left: 93, top: 0,
              child: _BlurCircle(
                width: AppSpacing.blurCircleLarge,
                height: AppSpacing.blurCircleLarge,
                radius: AppSpacing.blurBlueRadius,
                color: AppColors.blurBlueCenter,
              ),
            ),
            Positioned(
              left: 60, top: 380,
              child: _BlurCircle(
                width: AppSpacing.blurCyanWidth,
                height: AppSpacing.blurCyanHeight,
                radius: AppSpacing.blurCyanRadius,
                color: AppColors.blurCyanCenter,
              ),
            ),
          ],

        // Loading / not loaded — show default
        if (!bp.loaded)
          ...[
            Positioned(
              left: 0, top: 0,
              child: _BlurCircle(
                width: AppSpacing.blurCircleLarge,
                height: AppSpacing.blurCircleLarge,
                radius: AppSpacing.blurPinkRadius,
                color: AppColors.blurPinkCenter,
              ),
            ),
            Positioned(
              left: 93, top: 0,
              child: _BlurCircle(
                width: AppSpacing.blurCircleLarge,
                height: AppSpacing.blurCircleLarge,
                radius: AppSpacing.blurBlueRadius,
                color: AppColors.blurBlueCenter,
              ),
            ),
            Positioned(
              left: 60, top: 380,
              child: _BlurCircle(
                width: AppSpacing.blurCyanWidth,
                height: AppSpacing.blurCyanHeight,
                radius: AppSpacing.blurCyanRadius,
                color: AppColors.blurCyanCenter,
              ),
            ),
          ],

        // Content
        child,
      ],
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;

  const _BlurCircle({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}
