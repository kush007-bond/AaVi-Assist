class ObstaclePoint {
  final String label;
  final double distanceCm;
  final double angleDeg; // 0=ahead, -90=left, +90=right
  final String severity; // "danger" | "caution" | "info"

  const ObstaclePoint({
    required this.label,
    required this.distanceCm,
    required this.angleDeg,
    required this.severity,
  });

  factory ObstaclePoint.fromJson(Map<String, dynamic> j) => ObstaclePoint(
        label: j['label'] ?? 'obstacle',
        distanceCm: (j['distance_cm'] as num?)?.toDouble() ?? 150,
        angleDeg: (j['angle_deg'] as num?)?.toDouble() ?? 0,
        severity: j['severity'] ?? 'info',
      );
}

class NavigationData {
  final List<ObstaclePoint> obstacles;
  final double safeAngleDeg;
  final List<String> instructions;
  final String spokenInstruction;
  final bool isPathClear;
  final int processingMs;

  const NavigationData({
    required this.obstacles,
    required this.safeAngleDeg,
    required this.instructions,
    required this.spokenInstruction,
    required this.isPathClear,
    required this.processingMs,
  });

  factory NavigationData.fromJson(Map<String, dynamic> j) => NavigationData(
        obstacles: (j['obstacles'] as List? ?? [])
            .map((e) => ObstaclePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        safeAngleDeg: (j['safe_angle_deg'] as num?)?.toDouble() ?? 0,
        instructions: List<String>.from(j['instructions'] ?? ['Proceed carefully.']),
        spokenInstruction:
            j['spoken_instruction'] ?? 'Proceed slowly and carefully.',
        isPathClear: j['is_path_clear'] ?? true,
        processingMs: j['processing_ms'] ?? 0,
      );
}
