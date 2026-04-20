import 'package:flutter/material.dart';

class FigmaDropdownIcon extends StatelessWidget {
  final Color color;
  final double width;

  const FigmaDropdownIcon({
    super.key,
    this.color = const Color(0xFFC8C6C5),
    this.width = 12,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * (7.4 / 12);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _FigmaDropdownPainter(color: color)),
    );
  }
}

class _FigmaDropdownPainter extends CustomPainter {
  final Color color;

  const _FigmaDropdownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 12;
    final sy = size.height / 7.4;
    final path = Path()
      ..moveTo(6 * sx, 7.4 * sy)
      ..lineTo(0, 1.4 * sy)
      ..lineTo(1.4 * sx, 0)
      ..lineTo(6 * sx, 4.6 * sy)
      ..lineTo(10.6 * sx, 0)
      ..lineTo(12 * sx, 1.4 * sy)
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FigmaDropdownPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class FigmaSwapDirectionIcon extends StatelessWidget {
  final Color color;
  final double width;

  const FigmaSwapDirectionIcon({
    super.key,
    this.color = const Color(0xFFEA2A33),
    this.width = 16,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * (20 / 16);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _FigmaSwapDirectionPainter(color: color)),
    );
  }
}

class _FigmaSwapDirectionPainter extends CustomPainter {
  final Color color;

  const _FigmaSwapDirectionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 16;
    final sy = size.height / 20;

    final topArrow = Path()
      ..moveTo(4 * sx, 11 * sy)
      ..lineTo(4 * sx, 3.825 * sy)
      ..lineTo(1.425 * sx, 6.4 * sy)
      ..lineTo(0, 5 * sy)
      ..lineTo(5 * sx, 0)
      ..lineTo(10 * sx, 5 * sy)
      ..lineTo(8.575 * sx, 6.4 * sy)
      ..lineTo(6 * sx, 3.825 * sy)
      ..lineTo(6 * sx, 11 * sy)
      ..close();

    final bottomArrow = Path()
      ..moveTo(11 * sx, 20 * sy)
      ..lineTo(6 * sx, 15 * sy)
      ..lineTo(7.425 * sx, 13.6 * sy)
      ..lineTo(10 * sx, 16.175 * sy)
      ..lineTo(10 * sx, 9 * sy)
      ..lineTo(12 * sx, 9 * sy)
      ..lineTo(12 * sx, 16.175 * sy)
      ..lineTo(14.575 * sx, 13.6 * sy)
      ..lineTo(16 * sx, 15 * sy)
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    canvas.drawPath(topArrow, paint);
    canvas.drawPath(bottomArrow, paint);
  }

  @override
  bool shouldRepaint(covariant _FigmaSwapDirectionPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
