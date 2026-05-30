import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Circular "health %" gauge with the number in the middle.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    super.key,
    required this.percent,
    this.size = 168,
    this.label = 'health',
  });

  final int percent;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPercent(percent);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(percent / 100, color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$percent',
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  )),
              Text('% $label',
                  style: TextStyle(
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.fraction, this.color);
  final double fraction; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.14);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.65), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // full background ring
    canvas.drawCircle(center, radius, track);
    // value arc, starting at top
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
