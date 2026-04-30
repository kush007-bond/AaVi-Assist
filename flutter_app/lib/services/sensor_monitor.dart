import 'dart:async';
import 'dart:math';
import 'radar_service.dart';
import 'depth_service.dart';
import 'tts_service.dart';

enum AlertLevel { clear, info, caution, danger }

/// Simulation phases — idle keeps the display quiet between events.
enum _SimPhase { idle, approaching, receding }

class SensorAlert {
  final String message;
  final AlertLevel level;
  final double distanceCm;
  final double? angleDeg;
  final String source;       // "radar" | "lidar" | "tof" | "approaching" | "sim"
  final bool isSimulated;

  const SensorAlert({
    required this.message,
    required this.level,
    required this.distanceCm,
    this.angleDeg,
    required this.source,
    this.isSimulated = false,
  });
}

/// Local sensor monitor — polls radar + depth every 250 ms.
/// Zero network calls. Falls back to built-in simulation when
/// no hardware sensors are detected, so the feature always works.
///
/// Simulation behaviour:
///   idle      → sensor shows Clear (~320 cm), waits 3–8 s
///   approaching → obstacle closes from 290 cm → 28 cm over ~6–10 s
///   receding  → obstacle moves away from 28 cm → 320 cm over ~4–6 s
///   → back to idle
class SensorMonitor {
  static Timer? _timer;
  static bool _running = false;
  static double? _prevMinDistanceCm;

  // Simulation state machine
  static bool _simEnabled = false;
  static _SimPhase _simPhase = _SimPhase.idle;
  static double _simDist = 320.0;
  static double _simAngle = 0.0;
  static double _simSpeed = 0.0;   // always positive; direction set by phase
  static int _simIdleTicks = 0;    // countdown ticks before next approach
  static final _rng = Random();

  // TTS debounce
  static AlertLevel? _lastSpokenLevel;
  static DateTime? _lastSpokenAt;

  static final _ctrl = StreamController<SensorAlert?>.broadcast();

  /// Stream of current sensor state.
  /// null → clear (nothing detected within 300 cm)
  static Stream<SensorAlert?> get alerts => _ctrl.stream;

  static bool get isRunning => _running;
  static bool get simulationActive => _simEnabled;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  static void start() {
    if (_running) return;
    _running = true;
    _prevMinDistanceCm = null;
    _lastSpokenLevel = null;
    _lastSpokenAt = null;

    final hasHardware = RadarService.hasRadar || DepthService.hasDepth;
    if (!hasHardware) {
      _enableSimulation();
    }

    _timer = Timer.periodic(const Duration(milliseconds: 250), _poll);
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _simEnabled = false;
    _simPhase = _SimPhase.idle;
    _prevMinDistanceCm = null;
    _lastSpokenLevel = null;
    _ctrl.add(null);
  }

  /// Manually toggle simulation (e.g. from UI button).
  static void toggleSimulation() {
    if (_simEnabled) {
      _simEnabled = false;
    } else {
      _enableSimulation();
    }
  }

  static void _enableSimulation() {
    _simEnabled = true;
    _simPhase = _SimPhase.idle;
    _simDist = 320.0;
    _simAngle = _rng.nextDouble() * 60 - 30;
    _simSpeed = 0.0;
    // Wait 2–6 seconds before the first obstacle approaches
    _simIdleTicks = 8 + _rng.nextInt(16);
  }

  // ── Core poll ─────────────────────────────────────────────────────────────

  static Future<void> _poll(Timer _) async {
    bool isSimReading = false;
    List<_Reading> readings = [];

    // 1. Try real hardware first
    final radarData = await RadarService.getReadings();
    final depthData = await DepthService.getReadings();

    readings = [
      ...(radarData ?? []).map((r) => _Reading(
            source: 'radar',
            distanceCm: (r['distance_cm'] as num).toDouble(),
            angleDeg: (r['angle_deg'] as num?)?.toDouble() ?? 0,
          )),
      ...(depthData ?? []).map((d) => _Reading(
            source: d['source'] as String? ?? 'lidar',
            distanceCm: (d['distance_cm'] as num).toDouble(),
            angleDeg: (d['angle_deg'] as num?)?.toDouble() ?? 0,
          )),
    ];

    // 2. No hardware → run simulation
    if (readings.isEmpty && _simEnabled) {
      _advanceSim();
      readings = [
        _Reading(
          source: 'sim',
          distanceCm: _simDist,
          angleDeg: _simAngle,
        ),
      ];
      isSimReading = true;
    }

    if (readings.isEmpty) {
      _prevMinDistanceCm = null;
      _ctrl.add(null);
      return;
    }

    readings.sort((a, b) => a.distanceCm.compareTo(b.distanceCm));
    final closest = readings.first;
    final d = closest.distanceCm;
    final side = _sideStr(closest.angleDeg);
    final prev = _prevMinDistanceCm;

    SensorAlert? alert;

    // Approaching fast: closed >50 cm in a single 250 ms window
    if (prev != null && prev - d > 50) {
      alert = SensorAlert(
        message: 'Object approaching$side — ${d.toInt()} cm',
        level: AlertLevel.danger,
        distanceCm: d,
        angleDeg: closest.angleDeg,
        source: isSimReading ? 'sim' : 'approaching',
        isSimulated: isSimReading,
      );
    } else if (d < 30) {
      alert = SensorAlert(
        message: 'STOP — ${d.toInt()} cm${side.isEmpty ? " ahead" : side}',
        level: AlertLevel.danger,
        distanceCm: d,
        angleDeg: closest.angleDeg,
        source: closest.source,
        isSimulated: isSimReading,
      );
    } else if (d < 80) {
      alert = SensorAlert(
        message: 'Caution — ${d.toInt()} cm${side.isEmpty ? " ahead" : side}',
        level: AlertLevel.caution,
        distanceCm: d,
        angleDeg: closest.angleDeg,
        source: closest.source,
        isSimulated: isSimReading,
      );
    } else if (d < 300) {
      alert = SensorAlert(
        message: '${d.toInt()} cm${side.isEmpty ? " ahead" : side}',
        level: AlertLevel.info,
        distanceCm: d,
        angleDeg: closest.angleDeg,
        source: closest.source,
        isSimulated: isSimReading,
      );
    }
    // ≥ 300 cm → null (clear)

    _prevMinDistanceCm = d;
    _ctrl.add(alert);
    if (alert != null) _maybeTts(alert);
  }

  // ── Simulation state machine ───────────────────────────────────────────────

  static void _advanceSim() {
    // Small natural noise on angle
    _simAngle += _rng.nextDouble() * 1.2 - 0.6;
    _simAngle = _simAngle.clamp(-45.0, 45.0);

    switch (_simPhase) {
      case _SimPhase.idle:
        // Stay clearly above the 300 cm "clear" threshold — quiet display
        _simDist = 320.0 + _rng.nextDouble() * 10 - 5; // 315–325 cm jitter
        _simIdleTicks--;
        if (_simIdleTicks <= 0) {
          // Kick off a new approach event
          _simPhase = _SimPhase.approaching;
          _simDist = 295.0;
          // 2–4 cm per tick → takes ~65–130 ticks (~16–32 s) to reach 30 cm
          _simSpeed = 2.0 + _rng.nextDouble() * 2.0;
          _simAngle = _rng.nextDouble() * 60 - 30;
        }

      case _SimPhase.approaching:
        _simDist -= _simSpeed + (_rng.nextDouble() * 0.5 - 0.25);
        if (_simDist <= 28) {
          _simDist = 28.0;
          _simPhase = _SimPhase.receding;
          // Recede slightly faster so the "danger" phase doesn't linger
          _simSpeed = 4.0 + _rng.nextDouble() * 3.0;
        }

      case _SimPhase.receding:
        _simDist += _simSpeed + (_rng.nextDouble() * 0.5 - 0.25);
        if (_simDist >= 310) {
          _simDist = 320.0;
          _simPhase = _SimPhase.idle;
          // Idle for 3–10 seconds before next approach
          _simIdleTicks = 12 + _rng.nextInt(28);
          _simAngle = _rng.nextDouble() * 60 - 30;
        }
    }

    _simDist = _simDist.clamp(20.0, 330.0);
  }

  // ── TTS debounce ──────────────────────────────────────────────────────────

  static void _maybeTts(SensorAlert alert) {
    if (alert.level == AlertLevel.info) return; // info = visual only

    final now = DateTime.now();
    final cooldown = alert.level == AlertLevel.danger
        ? const Duration(seconds: 2)
        : const Duration(seconds: 4);

    if (_lastSpokenLevel == alert.level &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < cooldown) {
      return;
    }

    _lastSpokenLevel = alert.level;
    _lastSpokenAt = now;
    TtsService.speak(alert.message);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _sideStr(double? angle) {
    if (angle == null || angle.abs() < 10) return '';
    return angle > 0 ? ' on your right' : ' on your left';
  }
}

class _Reading {
  final String source;
  final double distanceCm;
  final double? angleDeg;
  const _Reading(
      {required this.source, required this.distanceCm, this.angleDeg});
}
