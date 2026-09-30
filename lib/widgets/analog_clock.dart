import 'dart:math';
import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';

class AnalogClock extends StatelessWidget {
  final DateTime time;
  final double size;

  const AnalogClock({super.key, required this.time, this.size = 280});

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ClockPainter(
          time: time,
          faceColor: theme.surface,
          rimColor: theme.borderMuted,
          handColor: theme.text,
          accentColor: theme.shaded(theme.primaryColor, 6),
          tickColor: theme.textDisabled,
          majorTickColor: theme.textMuted,
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime time;
  final Color faceColor;
  final Color rimColor;
  final Color handColor;
  final Color accentColor;
  final Color tickColor;
  final Color majorTickColor;

  const _ClockPainter({
    required this.time,
    required this.faceColor,
    required this.rimColor,
    required this.handColor,
    required this.accentColor,
    required this.tickColor,
    required this.majorTickColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Face
    canvas.drawCircle(center, radius - 2, Paint()..color = faceColor);

    // Rim
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Tick marks
    for (int i = 0; i < 60; i++) {
      final angle = i * 6 * pi / 180;
      final isHour = i % 5 == 0;
      final tickLen = isHour ? radius * 0.11 : radius * 0.05;
      final tickW = isHour ? 2.0 : 1.0;
      final outer = _point(center, radius - 5, angle);
      final inner = _point(center, radius - 5 - tickLen, angle);
      canvas.drawLine(
        outer,
        inner,
        Paint()
          ..color = isHour ? majorTickColor : tickColor
          ..strokeWidth = tickW
          ..strokeCap = StrokeCap.round,
      );
    }

    // Hour numbers (optional subtle)
    // Hour hand
    final hourAngle =
        ((time.hour % 12) + time.minute / 60 + time.second / 3600) *
            30 *
            pi /
            180;
    _drawHand(canvas, center, hourAngle, radius * 0.48, 4.5, handColor);

    // Minute hand
    final minuteAngle = (time.minute + time.second / 60) * 6 * pi / 180;
    _drawHand(canvas, center, minuteAngle, radius * 0.68, 3, handColor);

    // Second hand (with tail)
    final secondAngle = time.second * 6 * pi / 180;
    final secTip = _point(center, radius * 0.75, secondAngle);
    final secTail =
        _point(center, radius * 0.2, secondAngle + pi); // opposite direction
    canvas.drawLine(
      secTail,
      secTip,
      Paint()
        ..color = accentColor
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Center dot layers
    canvas.drawCircle(center, 7, Paint()..color = accentColor);
    canvas.drawCircle(center, 4, Paint()..color = faceColor);
    canvas.drawCircle(center, 2, Paint()..color = accentColor);
  }

  Offset _point(Offset center, double r, double angle) =>
      Offset(center.dx + r * sin(angle), center.dy - r * cos(angle));

  void _drawHand(Canvas canvas, Offset center, double angle, double length,
      double width, Color color) {
    canvas.drawLine(
      center,
      _point(center, length, angle),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.time != time;
}
