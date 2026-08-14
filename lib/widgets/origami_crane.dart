import 'package:flutter/material.dart';

/// 折纸鹤图标 — 与 App 图标(cranes.svg)一致的几何色块鹤。
///
/// 7 个多边形色块拼接而成(3 种蓝色调),直接用 CustomPainter 重绘,
/// 无图片资源依赖,任意尺寸缩放清晰。
class OrigamiCrane extends StatelessWidget {
  const OrigamiCrane({super.key, this.size = 96, this.gray = false});

  final double size;

  /// 灰色模式:三档蓝换成三档灰(保持明暗层次)。
  final bool gray;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CranePainter(gray: gray),
    );
  }
}

class _CranePainter extends CustomPainter {
  _CranePainter({required this.gray});

  final bool gray;

  /// cranes.svg 的几何色块(viewBox 135.46667):
  /// (颜色, 多边形顶点)。相对坐标已折算为绝对坐标。
  static const List<(Color, List<Offset>)> _shapes = [
    (
      Color(0xFF0088FA),
      [Offset(111.30, 58.17), Offset(37.42, 125.32), Offset(108.38, 108.84)],
    ),
    (
      Color(0xFF00C4FF),
      [Offset(127.97, 93.43), Offset(125.59, 78.13), Offset(120.40, 87.32)],
    ),
    (
      Color(0xFF00C4FF),
      [Offset(111.30, 58.17), Offset(58.93, 10.74), Offset(62.54, 102.48)],
    ),
    (
      Color(0xFF0088FA),
      [Offset(125.59, 78.13), Offset(110.25, 76.39), Offset(108.38, 108.84)],
    ),
    (
      Color(0xFF229BFF),
      [
        Offset(62.05, 89.96),
        Offset(62.54, 102.48),
        Offset(37.42, 125.32),
        Offset(7.95, 110.67),
      ],
    ),
    (
      Color(0xFF00C4FF),
      [Offset(78.36, 115.81), Offset(108.38, 108.84), Offset(84.90, 82.16)],
    ),
    (
      Color(0xFF229BFF),
      [Offset(108.38, 108.84), Offset(111.30, 58.17), Offset(84.90, 82.16)],
    ),
  ];

  /// 灰色模式配色:与原三档蓝一一对应(浅/中/深灰)。
  static const Color _grayLight = Color(0xFFD0D0D0);
  static const Color _grayMid = Color(0xFFB4B4B4);
  static const Color _grayDark = Color(0xFF909090);

  Color _colorOf(Color original) {
    if (!gray) return original;
    if (original == const Color(0xFF229BFF)) return _grayDark;
    if (original == const Color(0xFF00C4FF)) return _grayLight;
    return _grayMid;
  }

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
      paint.color = _colorOf(color);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CranePainter oldDelegate) =>
      oldDelegate.gray != gray;
}
