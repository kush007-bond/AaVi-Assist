import 'dart:math' as math;

/// A single obstacle point as returned by one room-map scan.
class MappedPoint {
  final String label;
  final double distanceCm;
  final double angleDeg;   // relative to scan heading (-90=left, 0=ahead, +90=right)
  final String severity;   // "danger" | "caution" | "info"

  // World coordinates (computed from heading + angle + distance)
  final double worldX; // positive = right
  final double worldY; // positive = forward

  const MappedPoint({
    required this.label,
    required this.distanceCm,
    required this.angleDeg,
    required this.severity,
    required this.worldX,
    required this.worldY,
  });

  factory MappedPoint.fromJson(
    Map<String, dynamic> j,
    double headingDeg,
  ) {
    final distance = (j['distance_cm'] as num?)?.toDouble() ?? 200.0;
    final relAngle = (j['angle_deg'] as num?)?.toDouble() ?? 0.0;
    // World angle = heading + relative angle (0° = forward/north)
    final worldAngle = (headingDeg + relAngle) * math.pi / 180.0;
    return MappedPoint(
      label: j['label'] ?? 'obstacle',
      distanceCm: distance,
      angleDeg: relAngle,
      severity: j['severity'] ?? 'info',
      worldX: distance * math.sin(worldAngle),
      worldY: distance * math.cos(worldAngle),
    );
  }
}

/// One completed scan at a specific heading.
class RoomScanResult {
  final int scanIndex;
  final double headingDeg;
  final List<MappedPoint> obstacles;
  final String walkingInstruction;

  const RoomScanResult({
    required this.scanIndex,
    required this.headingDeg,
    required this.obstacles,
    required this.walkingInstruction,
  });

  factory RoomScanResult.fromJson(Map<String, dynamic> j) {
    final heading = (j['heading_deg'] as num?)?.toDouble() ?? 0.0;
    final rawObs = j['obstacles'] as List? ?? [];
    return RoomScanResult(
      scanIndex: j['scan_index'] ?? 0,
      headingDeg: heading,
      obstacles: rawObs
          .map((e) => MappedPoint.fromJson(e as Map<String, dynamic>, heading))
          .toList(),
      walkingInstruction: j['walking_instruction'] ?? 'Scan complete.',
    );
  }
}
