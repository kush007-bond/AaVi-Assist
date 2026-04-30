import '../models/room_map_data.dart';

/// Manages the accumulated room-map state across multiple scans.
///
/// The user stands roughly in the same spot and rotates to scan 4 (then 8)
/// directions. Each scan adds obstacle points to the shared map.
class RoomMapService {
  // Predefined scan directions. The user steps through these in order.
  static const _scanDirections = [
    _ScanDir(heading: 0.0, label: 'Forward'),
    _ScanDir(heading: 90.0, label: 'Right'),
    _ScanDir(heading: 180.0, label: 'Behind'),
    _ScanDir(heading: 270.0, label: 'Left'),
    _ScanDir(heading: 45.0, label: 'Forward-Right'),
    _ScanDir(heading: 135.0, label: 'Behind-Right'),
    _ScanDir(heading: 225.0, label: 'Behind-Left'),
    _ScanDir(heading: 315.0, label: 'Forward-Left'),
  ];

  static final List<RoomScanResult> _scans = [];

  static List<RoomScanResult> get scans => List.unmodifiable(_scans);

  /// All accumulated obstacle world-points from all scans.
  static List<MappedPoint> get allPoints =>
      _scans.expand((s) => s.obstacles).toList();

  static int get completedScans => _scans.length;

  /// How many scan directions we require for a "complete" map.
  static const int requiredScans = 4;

  static bool get isComplete => _scans.length >= requiredScans;

  /// Coverage percentage: 0–100.
  static double get coveragePct =>
      (_scans.length / requiredScans * 100).clamp(0.0, 100.0);

  /// The heading for the NEXT scan (or current if not yet started).
  static double get nextHeading {
    final idx = _scans.length.clamp(0, _scanDirections.length - 1);
    return _scanDirections[idx].heading;
  }

  /// Human-readable label for the next scan direction.
  static String get nextDirectionLabel {
    final idx = _scans.length.clamp(0, _scanDirections.length - 1);
    return _scanDirections[idx].label;
  }

  /// Current scan index (0-based, passed to the backend).
  static int get currentScanIndex => _scans.length;

  /// Walking guidance spoken to the user before the current scan.
  static String guidanceForCurrentScan() {
    if (_scans.isEmpty) {
      return 'Stand still. Face forward and tap Scan to start mapping the room.';
    }
    if (isComplete) {
      return 'Room map is complete. You can tap Scan Again to refine any direction.';
    }
    final remaining = requiredScans - _scans.length;
    return 'Turn to face ${nextDirectionLabel.toLowerCase()} '
        'and tap Scan. $remaining scan${remaining == 1 ? "" : "s"} remaining.';
  }

  /// Add a completed scan result.
  static void addScan(RoomScanResult result) {
    _scans.add(result);
  }

  /// Clear all scans and start fresh.
  static void reset() {
    _scans.clear();
  }
}

class _ScanDir {
  final double heading;
  final String label;
  const _ScanDir({required this.heading, required this.label});
}
