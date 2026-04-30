import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/room_map_data.dart';

/// Top-down floor-plan painter.
/// Origin = user's standing position (centre of canvas).
/// Y+ = forward (up on screen), X+ = right.
class FloorPlanPainter extends CustomPainter {
  final List<MappedPoint> points;
  final double scale; // pixels per cm
  final bool compact; // compact mode = smaller labels

  static const double defaultScale = 0.55; // ~55% pixel-per-cm

  const FloorPlanPainter({
    required this.points,
    this.scale = defaultScale,
    this.compact = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawGrid(canvas, cx, cy, size);
    _drawPoints(canvas, cx, cy);
    _drawUser(canvas, cx, cy);
  }

  void _drawGrid(Canvas canvas, double cx, double cy, Size size) {
    final gridPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Concentric rings every 100 cm
    for (final rangeCm in [100.0, 200.0, 300.0]) {
      final r = rangeCm * scale;
      canvas.drawCircle(Offset(cx, cy), r, gridPaint);

      if (!compact) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${rangeCm.toInt()}cm',
            style: TextStyle(
                color: Colors.green.withValues(alpha: 0.35), fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx + r + 2, cy - 8));
      }
    }

    // Cross-hairs
    final crossPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), crossPaint);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), crossPaint);

    // "AHEAD" label
    if (!compact) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'AHEAD',
          style: TextStyle(
              color: Colors.green.withValues(alpha: 0.45), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, 6));
    }
  }

  void _drawPoints(Canvas canvas, double cx, double cy) {
    for (final pt in points) {
      final px = cx + pt.worldX * scale;
      final py = cy - pt.worldY * scale; // Y-up on screen = Y- in canvas

      final color = _severityColor(pt.severity);
      final dotR = compact ? 5.0 : (pt.severity == 'danger' ? 9.0 : 7.0);

      // Glow ring for danger
      if (pt.severity == 'danger') {
        canvas.drawCircle(
          Offset(px, py),
          dotR + 5,
          Paint()
            ..color = color.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawCircle(
        Offset(px, py),
        dotR,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      if (!compact) {
        final tp = TextPainter(
          text: TextSpan(
            text: pt.label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 70);
        tp.paint(canvas, Offset(px - tp.width / 2, py + dotR + 2));
      }
    }
  }

  void _drawUser(Canvas canvas, double cx, double cy) {
    // White circle with green border
    canvas.drawCircle(Offset(cx, cy), 10,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), 10,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Forward triangle
    final tri = Path()
      ..moveTo(cx, cy - 7)
      ..lineTo(cx - 4, cy + 4)
      ..lineTo(cx + 4, cy + 4)
      ..close();
    canvas.drawPath(tri, Paint()..color = Colors.green);

    if (!compact) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'YOU',
          style: TextStyle(
              color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + 13));
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'danger':
        return Colors.red;
      case 'caution':
        return Colors.orange;
      default:
        return Colors.yellow.shade600;
    }
  }

  @override
  bool shouldRepaint(FloorPlanPainter old) => old.points != points;
}

/// Compact floor-plan widget for embedding in the home screen.
class MiniMapWidget extends StatelessWidget {
  final List<MappedPoint> points;
  final double size;
  final VoidCallback? onTap;

  const MiniMapWidget({
    super.key,
    required this.points,
    this.size = 110,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF050F05),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.4),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              CustomPaint(
                painter: FloorPlanPainter(
                  points: points,
                  scale: 0.28,
                  compact: true,
                ),
                size: Size(size, size),
              ),
              if (points.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_view,
                          color: Colors.green.withValues(alpha: 0.3), size: 20),
                      const SizedBox(height: 4),
                      Text(
                        'Map Room',
                        style: TextStyle(
                          color: Colors.green.withValues(alpha: 0.5),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              // Tap hint overlay
              Positioned(
                bottom: 3,
                right: 4,
                child: Icon(Icons.open_in_new,
                    color: Colors.green.withValues(alpha: 0.4), size: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format the coverage for display, e.g. "3/4 scans"
  static String coverageLabel(int completed, int required) =>
      '$completed/$required scans';
}

/// Angle sweep arc showing which directions have been scanned.
class ScanCoverageArc extends CustomPainter {
  final List<double> scannedHeadings; // degrees, 0=forward
  static const double sweepHalf = 45.0; // each scan covers ±45°

  const ScanCoverageArc({required this.scannedHeadings});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 4;

    final paint = Paint()
      ..color = Colors.green.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    for (final heading in scannedHeadings) {
      // Convert heading to canvas angle: 0°=up (forward), clockwise
      final startRad =
          (heading - sweepHalf - 90) * math.pi / 180; // canvas 0=right
      final sweepRad = sweepHalf * 2 * math.pi / 180;

      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          startRad,
          sweepRad,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ScanCoverageArc old) =>
      old.scannedHeadings != scannedHeadings;
}
