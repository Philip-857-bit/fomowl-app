import 'package:flutter/material.dart';
import '../../../../constants/app_colors.dart';

class TokenChartCard extends StatelessWidget {
  final bool isLoading;
  final List<double> data;

  const TokenChartCard({
    super.key,
    required this.isLoading,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = data.where((v) => v.isFinite && v > 0).toList();
    return Container(
      height: 170,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFF050505)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentRed, strokeWidth: 2))
          : chartData.isEmpty
              ? const Center(child: Text('No chart data', style: TextStyle(color: Colors.white38)))
              : CustomPaint(
                  size: const Size(double.infinity, double.infinity),
                  painter: _ChartPainter(
                    data: chartData,
                    lineColor: chartData.last >= chartData.first ? AppColors.success : AppColors.error,
                  ),
                ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _ChartPainter({required this.data, this.lineColor = AppColors.success});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;

    // Stable assets (e.g., USDT) can have a flat series. Draw a centered flat line.
    if (data.length < 2 || range == 0) {
      final y = size.height * 0.55;
      final flatPath = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y);
      canvas.drawPath(flatPath, paint);

      final fillPath = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            lineColor.withValues(alpha: 0.12),
            lineColor.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
      return;
    }

    final step = size.width / (data.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - ((data[i] - minVal) / range * size.height * 0.85 + size.height * 0.05);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset(
        points[i - 1].dx + (points[i].dx - points[i - 1].dx) / 2,
        points[i - 1].dy,
      );
      final cp2 = Offset(
        points[i - 1].dx + (points[i].dx - points[i - 1].dx) / 2,
        points[i].dy,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.15),
          lineColor.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => oldDelegate.data != data;
}
