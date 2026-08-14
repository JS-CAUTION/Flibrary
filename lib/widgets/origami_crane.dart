import 'package:flutter/material.dart';

/// 折纸鹤图标 — 与 App 图标(cranes.svg)同几何结构的色块鹤。
///
/// 7 个多边形色块拼接而成,配色为蓝/青/蓝紫渐变系(比原图标三蓝更有层次),
/// 整体 80% 透明度,直接 CustomPainter 重绘,任意尺寸缩放清晰。
class OrigamiCrane extends StatelessWidget {
  const OrigamiCrane({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _CranePainter(),
    );
  }
}

class _CranePainter extends CustomPainter {
  const _CranePainter();

  /// cranes.svg 的几何色块(viewBox 135.46667):
  /// (配色, 多边形顶点)。相对坐标已折算为绝对坐标。
  /// 配色:鲜艳暖色系为主(粉红/橙/黄/红/青绿),折痕用蓝紫阴影,整体 80% 透明度。
  static const double _opacity = 0.8;
  static const Color _pink = Color(0xFFFF5C8A); // 粉红(主翼)
  static const Color _orange = Color(0xFFFF8A3D); // 橙(头颈)
  static const Color _yellow = Color(0xFFFFC93D); // 黄(身体颈)
  static const Color _red = Color(0xFFFF4D4D); // 红(翅前)
  static const Color _teal = Color(0xFF2EC4B6); // 青绿(尾羽)
  static const Color _blue = Color(0xFF33A1FD); // 蓝(腹面)
  static const Color _shadow = Color(0xFF7A5BF0); // 蓝紫(折痕阴影)

  static final List<(Color, List<Offset>)> _shapes = [
    (
      _pink,
      [Offset(111.30, 58.17), Offset(37.42, 125.32), Offset(108.38, 108.84)],
    ),
    (
      _orange,
      [Offset(127.97, 93.43), Offset(125.59, 78.13), Offset(120.40, 87.32)],
    ),
    (
      _yellow,
      [Offset(111.30, 58.17), Offset(58.93, 10.74), Offset(62.54, 102.48)],
    ),
    (
      _red,
      [Offset(125.59, 78.13), Offset(110.25, 76.39), Offset(108.38, 108.84)],
    ),
    (
      _teal,
      [
        Offset(62.05, 89.96),
        Offset(62.54, 102.48),
        Offset(37.42, 125.32),
        Offset(7.95, 110.67),
      ],
    ),
    (
      _blue,
      [Offset(78.36, 115.81), Offset(108.38, 108.84), Offset(84.90, 82.16)],
    ),
    (
      _shadow,
      [Offset(108.38, 108.84), Offset(111.30, 58.17), Offset(84.90, 82.16)],
    ),
  ];

  static const double _viewBox = 135.46667;

  @override
  void paint(Canvas canvas, Size size) {
    // 留 6% 边距,居中缩放
    const padding = 0.06;
    final scale = size.width * (1 - padding * 2) / _viewBox;
    final offset = Offset(size.width * padding, size.height * padding);

    final paint = Paint()..style = PaintingStyle.fill;
    for (final (color, points) in _shapes) {
      final path = Path()
        ..moveTo(points.first.dx * scale + offset.dx,
            points.first.dy * scale + offset.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx * scale + offset.dx, p.dy * scale + offset.dy);
      }
      path.close();
      paint.color = color.withValues(alpha: _opacity);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CranePainter oldDelegate) => false;
}
