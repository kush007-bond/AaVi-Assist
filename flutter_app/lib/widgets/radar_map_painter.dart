import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/navigation_data.dart';

class RadarMapPainter extends CustomPainter {
  final List<ObstaclePoint> obstacles;
  final double safeAngleDeg;
  final bool isPathClear;

  // Maximum range to display (cm). Obstacles beyond this are clamped to edge.
  static const double maxRangeCm = 300;

  RadarMapPainter({
    required this.obstacles,
    required this.safeAngleDeg,
    required this.isPathClear,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72; // user icon sits at 72% down
    final radius = math.min(cx, cy) * 0.92;

    _drawGrid(canvas, cx, cy, radius);
    _drawSafePath(canvas, cx, cy, radius);
    _drawObstacles(canvas, cx, cy, radius);
    _drawUser(canvas, cx, cy);
  }

  // ── Polar grid ─────────────────────────────────────────────────────────

  void _drawGrid(Canvas canvas, double cx, double cy, double radius) {
    final gridPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: Colors.green.withValues(alpha: 0.5),
      fontSize: 10,
    );

    // Distance rings: 100 cm, 200 cm, 300 cm
    for (final double rangeCm in [100.0, 200.0, 300.0]) {
      final r = (rangeCm / maxRangeCm) * radius;
      canvas.drawCircle(Offset(cx, cy), r, gridPaint);

      // Label
      final tp = TextPainter(
        text: TextSpan(text: '${rangeCm.toInt()}cm', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + r + 2, cy - 8));
    }

    // Angle lines every 30°
    final anglePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    for (int deg = -90; deg <= 90; deg += 30) {
      final rad = _toRad(deg.toDouble());
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + radius * math.sin(rad), cy - radius * math.cos(rad)),
        anglePaint,
      );
    }

    // Forward label
    final fwdTp = TextPainter(
      text: TextSpan(
        text: 'AHEAD',
        style: TextStyle(color: Colors.green.withValues(alpha: 0.6), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    fwdTp.paint(canvas, Offset(cx - fwdTp.width / 2, cy - radius - 18));
  }

  // ── Safe path arrow ─────────────────────────────────────────────────────

  void _drawSafePath(Canvas canvas, double cx, double cy, double radius) {
    final color = isPathClear ? Colors.green : Colors.orange;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rad = _toRad(safeAngleDeg);
    final arrowLen = radius * 0.75;
    final ex = cx + arrowLen * math.sin(rad);
    final ey = cy - arrowLen * math.cos(rad);

    // Shaft
    canvas.drawLine(Offset(cx, cy), Offset(ex, ey), paint);

    // Arrowhead
    const headLen = 18.0;
    const headAngle = 0.4; // radians
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final angle = math.atan2(ey - cy, ex - cx);
    canvas.drawLine(
      Offset(ex, ey),
      Offset(ex - headLen * math.cos(angle - headAngle),
          ey - headLen * math.sin(angle - headAngle)),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(ex, ey),
      Offset(ex - headLen * math.cos(angle + headAngle),
          ey - headLen * math.sin(angle + headAngle)),
      arrowPaint,
    );

    // "SAFE PATH" label near arrowhead
    final labelTp = TextPainter(
      text: TextSpan(
        text: isPathClear ? 'SAFE PATH' : 'CAUTION',
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas, Offset(ex - labelTp.width / 2, ey - 18));
  }

  // ── Obstacles ───────────────────────────────────────────────────────────

  void _drawObstacles(Canvas canvas, double cx, double cy, double radius) {
    for (final obs in obstacles) {
      final color = _severityColor(obs.severity);
      final clampedDist = obs.distanceCm.clamp(10.0, maxRangeCm);
      final r = (clampedDist / maxRangeCm) * radius;
      final rad = _toRad(obs.angleDeg);
      final ox = cx + r * math.sin(rad);
      final oy = cy - r * math.cos(rad);

      // Pulse ring for danger
      if (obs.severity == 'danger') {
        canvas.drawCircle(
          Offset(ox, oy),
          18,
          Paint()
            ..color = color.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill,
        );
      }

      // Filled dot
      canvas.drawCircle(
        Offset(ox, oy),
        obs.severity == 'danger' ? 10 : 7,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: obs.label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);
      tp.paint(canvas, Offset(ox - tp.width / 2, oy + 12));

      // Distance label
      final distTp = TextPainter(
        text: TextSpan(
          text: '${obs.distanceCm.toInt()}cm',
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      distTp.paint(canvas, Offset(ox - distTp.width / 2, oy - 20));
    }
  }

  // ── User icon ───────────────────────────────────────────────────────────

  void _drawUser(Canvas canvas, double cx, double cy) {
    // Body circle
    canvas.drawCircle(
      Offset(cx, cy),
      14,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      14,
      Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Direction triangle pointing up (forward)
    final triPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(cx, cy - 9)
      ..lineTo(cx - 5, cy + 5)
      ..lineTo(cx + 5, cy + 5)
      ..close();
    canvas.drawPath(path, triPaint);

    // "YOU" label
    final tp = TextPainter(
      text: const TextSpan(
        text: 'YOU',
        style: TextStyle(
          color: Colors.green,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 17));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  double _toRad(double deg) => deg * math.pi / 180;

  Color _severityColor(String severity) {
    switch (severity) {
      case 'danger':
        return Colors.red;
      case 'caution':
        return Colors.orange;
      default:
        return Colors.yellow;
    }
  }

  @override
  bool shouldRepaint(RadarMapPainter old) =>
      old.obstacles != obstacles ||
      old.safeAngleDeg != safeAngleDeg ||
      old.isPathClear != isPathClear;
}
